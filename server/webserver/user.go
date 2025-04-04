package webserver

import (
	"encoding/json"
	"io"
	"myfileserver/db"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

func (ws *WebServer) ReqGetUserList() gin.HandlerFunc {
	return func(c *gin.Context) {
		users, err := ws.Database.GetUsers()
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "success",
			"data":    users,
		})
	}
}

func (ws *WebServer) ReqDeleteUser() gin.HandlerFunc {
	return func(c *gin.Context) {
		user_id := c.Query("user_id")
		if user_id == "" {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "user_id is empty",
			})
			return
		}
		val, err := strconv.ParseInt(user_id, 10, 64)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		loginUserInfo := getLoginUser(c)
		userEntry, err := ws.Database.GetUserById(val)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		// 管理员不能删除管理员自己
		if userEntry.Id == loginUserInfo.UserEntry.Id {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "permission denied",
			})
			return
		}
		err = ws.Database.DeleteUser(val)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}

		ws.Database.AddUserHistory(db.UserHistoryEntry{
			UserId:   loginUserInfo.UserEntry.Id,
			UserName: loginUserInfo.UserEntry.Name,
			Action:   "delete_user",
			Information: ws.getRequestInfo(c, map[string]string{
				"user_id":    strconv.FormatInt(userEntry.Id, 10),
				"user_name":  userEntry.Name,
				"user_email": userEntry.Email,
			}),
			Ip: c.ClientIP(),
		})
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "delete user succeed",
		})
	}
}

func (ws *WebServer) ReqUpdateUser() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer c.Request.Body.Close()
		data, err := io.ReadAll(c.Request.Body)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		userEntry := db.UserEntry{}
		err = json.Unmarshal(data, &userEntry)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		currUserEntry, err := ws.Database.GetUserById(userEntry.Id)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		loginUserInfo := getLoginUser(c)
		if loginUserInfo.UserEntry.Id != userEntry.Id && !loginUserInfo.UserEntry.IsAdmin {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "permission denied",
			})
			return
		}
		if userEntry.Password == "" {
			userEntry.Password = currUserEntry.Password
		}
		err = ws.Database.UpdateUser(userEntry)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}

		ws.Database.AddUserHistory(db.UserHistoryEntry{
			UserId:   loginUserInfo.UserEntry.Id,
			UserName: loginUserInfo.UserEntry.Name,
			Action:   "update_user",
			Information: ws.getRequestInfo(c, map[string]string{
				"user_id":    strconv.FormatInt(userEntry.Id, 10),
				"user_name":  userEntry.Name,
				"user_email": userEntry.Email,
			}),
			Ip: c.ClientIP(),
		})
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "update succeed",
		})
	}
}

func (ws *WebServer) ReqCreateUser() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer c.Request.Body.Close()
		data, err := io.ReadAll(c.Request.Body)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		loginUserInfo := getLoginUser(c)
		if !loginUserInfo.UserEntry.IsAdmin {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "permission denied",
			})
			return
		}
		userEntry := db.UserEntry{}
		err = json.Unmarshal(data, &userEntry)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		err = ws.Database.AddUser(userEntry)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}

		ws.Database.AddUserHistory(db.UserHistoryEntry{
			UserId:   loginUserInfo.UserEntry.Id,
			UserName: loginUserInfo.UserEntry.Name,
			Action:   "create_user",
			Information: ws.getRequestInfo(c, map[string]string{
				"user_id":    strconv.FormatInt(userEntry.Id, 10),
				"user_name":  userEntry.Name,
				"user_email": userEntry.Email,
			}),
			Ip: c.ClientIP(),
		})
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "create succeed",
		})
	}
}

func (ws *WebServer) ReqGetUserSetting() gin.HandlerFunc {
	return func(c *gin.Context) {
		_user_id := c.Query("user_id")
		if _user_id == "" {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "user_id is empty",
			})
			return

		}
		user_id, err := strconv.ParseInt(_user_id, 10, 64)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		userSessionId := c.GetHeader("session-id")
		if userSessionId == "" {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "user_id is empty",
			})
			return
		}
		GetInstance().Lock.Lock()
		userInfo, exist := GetInstance().Tokens[userSessionId]
		GetInstance().Lock.Unlock()
		if !exist {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "user is not exist",
			})
			return
		}

		// 如果不是管理员，只能查看自己的设置
		if userInfo.UserEntry.Id != user_id && !userInfo.UserEntry.IsAdmin {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "user is not admin",
			})
			return
		}

		if user_id != 0 {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "user_id is not 0",
			})
			return
		}
		key := c.Query("key")
		if key == "" {
			settings, err := ws.Database.GetUserSettings(user_id)
			if err != nil {
				c.JSON(http.StatusOK, gin.H{
					"code":    1000,
					"message": err.Error(),
				})
				return
			}
			c.JSON(http.StatusOK, gin.H{
				"code":    0,
				"message": "success",
				"data":    settings,
			})
			return
		}
		val, err := ws.Database.GetUserSetting(user_id, key)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "success",
			"data":    val,
		})
	}
}

type UserSetting struct {
	UserId int64  `json:"user_id"`
	Key    string `json:"key"`
	Value  string `json:"value"`
}

func (ws *WebServer) ReqSetUserSetting() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer c.Request.Body.Close()
		data, err := io.ReadAll(c.Request.Body)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		userSetting := UserSetting{}
		err = json.Unmarshal(data, &userSetting)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		loginUserInfo := getLoginUser(c)

		// 如果不是管理员，只能修改自己的设置
		if loginUserInfo.UserEntry.Id != userSetting.UserId && !loginUserInfo.UserEntry.IsAdmin {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "user is not admin",
			})
			return
		}

		err = ws.Database.SetUserSetting(userSetting.UserId, userSetting.Key, userSetting.Value)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}

		userEntry, err := ws.Database.GetUserById(userSetting.UserId)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		ws.Database.AddUserHistory(db.UserHistoryEntry{
			UserId:   loginUserInfo.UserEntry.Id,
			UserName: loginUserInfo.UserEntry.Name,
			Action:   "change_user_setting",
			Information: ws.getRequestInfo(c, map[string]string{
				"user_id":            strconv.FormatInt(userSetting.UserId, 10),
				"user_name":          userEntry.Name,
				"user_setting_key":   userSetting.Key,
				"user_setting_value": userSetting.Value,
			}),
			Ip: c.ClientIP(),
		})
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "success",
		})
	}
}

func (ws *WebServer) ReqGetUserHistory() gin.HandlerFunc {
	return func(c *gin.Context) {
		_user_id := c.Query("user_id")
		if _user_id == "" {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "user_id is empty",
			})
			return
		}
		user_id, err := strconv.ParseInt(_user_id, 10, 64)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}

		loginUserInfo := getLoginUser(c)
		// 如果不是管理员，只能查看自己的历史记录
		if loginUserInfo.UserEntry.Id != user_id && !loginUserInfo.UserEntry.IsAdmin {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "user is not admin",
			})
			return
		}
		histories, err := ws.Database.GetUserHistory(user_id)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "success",
			"data":    histories,
		})
	}
}
