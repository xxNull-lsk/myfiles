package webserver

import (
	"encoding/json"
	"myfileserver/db"
	"myfileserver/lib"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

type LoginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

func (ws *WebServer) ReqLogout() gin.HandlerFunc {
	return func(c *gin.Context) {
		userSessionId := c.GetHeader("session-id")
		loginUserInfo := getLoginUser(c)
		ws.Database.AddUserHistory(db.UserHistoryEntry{
			UserId:   loginUserInfo.UserEntry.Id,
			UserName: loginUserInfo.UserEntry.Name,
			Action:   "logout",
			Information: ws.getRequestInfo(c, map[string]string{
				"user_session_id": userSessionId,
			}),
			Ip: c.ClientIP(),
		})

		GetInstance().Lock.Lock()
		delete(GetInstance().Tokens, userSessionId)
		GetInstance().Lock.Unlock()
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "退出成功",
		})
	}
}

func (ws *WebServer) getRequestInfo(c *gin.Context, actionInfo map[string]string) string {
	info := make(map[string]interface{})
	info["ip"] = c.ClientIP()
	info["session_id"] = c.GetHeader("session-id")
	info["user_agent"] = c.Request.UserAgent()
	info["header"] = c.Request.Header
	info["url"] = c.Request.RequestURI
	info["method"] = c.Request.Method
	info["action_info"] = actionInfo
	information, _ := json.Marshal(info)
	return string(information)
}

func (ws *WebServer) getUserEntryByID(userId int64) (*db.UserEntry, error) {
	userEntry, err := ws.Database.GetUserById(userId)
	if err != nil {
		return nil, err
	}
	if !userEntry.Enabled {
		return nil, err
	}

	userEntry.LastLoginAt = time.Now().Format(time.DateTime)
	ws.Database.UpdateUserLastLoginAt(userEntry)
	return &userEntry, nil
}

func (ws *WebServer) getUserEntry(username string) (*db.UserEntry, error) {
	userEntry, err := ws.Database.GetUser(username)
	if err != nil {
		return nil, err
	}
	if !userEntry.Enabled {
		return nil, err
	}
	return &userEntry, nil
}

func (ws *WebServer) ReqLogin() gin.HandlerFunc {
	return func(c *gin.Context) {
		req := LoginRequest{}
		err := c.ShouldBindJSON(&req)
		if err != nil {
			lib.Logger.Error("invalid body: ", err, "username: ", req.Username)
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		userEntry, err := ws.getUserEntry(req.Username)
		if err != nil {
			lib.Logger.Error("get user entry error: ", err, "username: ", req.Username)
			c.JSON(http.StatusOK, gin.H{
				"code":    1001,
				"message": "用户或密码错误",
			})
			return
		}
		userSessionId := c.GetHeader("session-id")
		userToken := c.GetHeader("user-token")
		if req.Password != "" {
			if userEntry.Password != req.Password {
				lib.Logger.Error("bad password!", "username: ", req.Username, "|", req.Password, "|", userEntry.Password, "|")
				c.JSON(http.StatusOK, gin.H{
					"code":    1001,
					"message": "用户名或密码错误",
				})
				return
			}
			oldUserSessionID := userSessionId
			userSessionId = ""
			userToken, _ = lib.GenerateRandomString(16)
			GetInstance().Lock.Lock()
			if oldUserSessionID != "" {
				delete(GetInstance().Tokens, oldUserSessionID)
			}
			for {
				userSessionId, _ = lib.GenerateRandomString(16)
				_, exist := GetInstance().Tokens[userSessionId]
				if !exist {
					GetInstance().Tokens[userSessionId] = UserInfo{
						UserName:     req.Username,
						UserToken:    userToken,
						LoginAt:      time.Now(),
						FirstLoginAt: time.Now(),
						UserEntry:    *userEntry,
					}
					break
				}
			}
			GetInstance().Lock.Unlock()
			lib.Logger.Error("user login with password succeed!", " user_id:", userEntry.Id, " username:", req.Username)
		} else {
			if userSessionId != "" && userToken != "" {
				GetInstance().Lock.Lock()
				loginUserInfo, exist := GetInstance().Tokens[userSessionId]
				// 如果上次登录时间超过7天，就认为删除
				// 如果第一次登录时间超过30天，也认为过期
				if !exist ||
					loginUserInfo.UserEntry.Name != req.Username ||
					time.Since(loginUserInfo.LoginAt).Hours() > 7*24 ||
					time.Since(loginUserInfo.FirstLoginAt).Hours() > 30*24 {
					delete(GetInstance().Tokens, userSessionId)
					GetInstance().Lock.Unlock()
					lib.Logger.Error("user login failed! token expried.", "username: ", req.Username)
					c.JSON(http.StatusOK, gin.H{
						"code":    1001,
						"message": "Token已过期",
					})
					return
				}
				loginUserInfo.UserToken, _ = lib.GenerateRandomString(16)
				userToken = loginUserInfo.UserToken
				loginUserInfo.LoginAt = time.Now()
				loginUserInfo.UserEntry = *userEntry
				GetInstance().Tokens[userSessionId] = loginUserInfo
				GetInstance().Lock.Unlock()
				lib.Logger.Error("user login with session id succeed!", " user_id:", loginUserInfo.UserEntry.Id, " username:", req.Username)
			}
		}
		userEntry.Password = ""
		userSettingEntries, err := ws.Database.GetUserSettings(userEntry.Id)
		if err != nil {
			lib.Logger.Error("get user setting failed!", err)
			c.JSON(http.StatusOK, gin.H{
				"code":    1001,
				"message": "获取用户设置失败",
			})
			return
		}
		settings := make(map[string]string)
		for _, userSettingEntry := range userSettingEntries {
			settings[userSettingEntry.Key] = userSettingEntry.Value
		}
		if userEntry.Id != 0 {
			userEntry.LastLoginAt = time.Now().Format(time.DateTime)
			ws.Database.UpdateUserLastLoginAt(*userEntry)
		}

		ws.Database.AddUserHistory(db.UserHistoryEntry{
			UserId:   userEntry.Id,
			UserName: userEntry.Name,
			Action:   "login",
			Information: ws.getRequestInfo(c, map[string]string{
				"user_session_id": userSessionId,
			}),
			Ip: c.ClientIP(),
		})
		lib.Logger.Error("user login succeed!", " user_id:", userEntry.Id, " username:", req.Username)
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "登录成功",
			"data": gin.H{
				"session_id": userSessionId,
				"user_token": userToken,
				"user":       userEntry,
				"settings":   settings,
			},
		})
	}
}
