package webserver

import (
	"encoding/json"
	"fmt"
	"log"
	"myfileserver/db"
	"myfileserver/lib"
	"net/http"
	"os"
	"path/filepath"

	"github.com/gin-gonic/gin"
)

type WebServer struct {
	InstallMode bool
	RootDir     string
	TempDir     string
	Database    db.Database
}

func (ws *WebServer) ReqVersion() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "success",
			"data": gin.H{
				"install_mode": ws.InstallMode,
				"version":      lib.AppVersion,
				"commit":       lib.AppCommitID,
				"time":         lib.AppTime,
				"name":         lib.AppName,
				"url":          lib.ProjectURL,
			},
		})
	}
}

func AuthSharedMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		sid := c.Query("sid")
		if sid == "" {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "sid is empty",
			})
			c.Abort() // 停止后续处理
			return
		}
		sharedEntry, err := GetInstance().Database.GetShared(sid)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    404,
				"message": err.Error(),
			})
			c.Abort() // 停止后续处理
			return
		}

		code := c.Query("code")
		if code != sharedEntry.Code {
			c.JSON(http.StatusOK, gin.H{
				"code":    1001,
				"message": "code invalid",
			})
			c.Abort() // 停止后续处理
			return
		}

		c.Next()
	}
}

func MiddlewareInstall(ws *WebServer) gin.HandlerFunc {
	return func(c *gin.Context) {
		if ws.InstallMode {
			if c.Request.URL.Path == "/front/install/index.html" {
				c.Next()
				return
			}
			lib.Logger.Info("install mode, goto install page")
			c.Redirect(http.StatusFound, "/front/install/index.html")
			c.Abort()
			return
		}
		c.Next()
	}
}

func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 通过cookie校验用户身份
		userSessionId, _ := c.Cookie("session-id")
		userToken, _ := c.Cookie("user-token")
		// 通过head校验用户身份
		if userSessionId == "" && userToken == "" {
			userSessionId = c.GetHeader("session-id")
			userToken = c.GetHeader("user-token")
		}
		// 通过参数校验用户身份
		if userSessionId == "" && userToken == "" {
			userSessionId = c.Query("session-id")
			userToken = c.Query("user-token")
		}
		if userSessionId != "" && userToken != "" {
			GetInstance().Lock.Lock()
			userInfo, exist := GetInstance().Tokens[userSessionId]
			GetInstance().Lock.Unlock()
			if !exist {
				fmt.Println("user not login!", userSessionId, userToken)
				c.JSON(http.StatusUnauthorized, gin.H{
					"code":    1000,
					"message": "Unauthorized",
				})
				c.Abort() // 停止后续处理
				return
			}
			if userInfo.UserToken == userToken && userInfo.UserEntry.Enabled {
				//fmt.Println("check user token succeed!", token)
				c.Next()
				return
			}
			fmt.Println("check user token failed!", userInfo.UserToken, userToken)
		}
		// 校验失败
		c.JSON(http.StatusUnauthorized, gin.H{
			"code":    1000,
			"message": "Unauthorized",
		})
		c.Abort() // 停止后续处理
	}
}

func AuthAdminMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 通过cookie校验用户身份
		userSessionId, _ := c.Cookie("session-id")
		userToken, _ := c.Cookie("user-token")
		// 通过head校验用户身份
		if userSessionId == "" && userToken == "" {
			userSessionId = c.GetHeader("session-id")
			userToken = c.GetHeader("user-token")
		}
		// 通过参数校验用户身份
		if userSessionId == "" && userToken == "" {
			userSessionId = c.Query("session-id")
			userToken = c.Query("user-token")
		}
		if userSessionId != "" && userToken != "" {
			GetInstance().Lock.Lock()
			userInfo, exist := GetInstance().Tokens[userSessionId]
			GetInstance().Lock.Unlock()
			if !exist {
				fmt.Println("user not login!", userSessionId, userToken)
				c.JSON(http.StatusUnauthorized, gin.H{
					"code":    1000,
					"message": "Unauthorized",
				})
				c.Abort() // 停止后续处理
				return
			}
			if userInfo.UserToken == userToken && userInfo.UserEntry.IsAdmin && userInfo.UserEntry.Enabled {
				//fmt.Println("check user token succeed!", token)
				c.Next()
				return
			}
			fmt.Println("check user token failed!", userInfo.UserToken, userToken)
		}

		// 校验失败
		c.JSON(http.StatusUnauthorized, gin.H{
			"code":    1000,
			"message": "Unauthorized",
		})
		c.Abort() // 停止后续处理
	}
}

type InstallRequest struct {
	Logger   lib.ConfigLogger `json:"logger"`
	Server   lib.ServerConfig `json:"server"`
	UserName string           `json:"user_name"`
	Password string           `json:"password"`
}

func (ws *WebServer) ReqGetInstall(cfg *lib.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		if !ws.InstallMode {
			lib.Logger.Error("install mode is off!")
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "install mode is off",
			})
		}
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "success",
			"data": gin.H{
				"logger": cfg.Logger,
				"server": cfg.Server,
				"app": gin.H{
					"version": lib.AppVersion,
					"commit":  lib.AppCommitID,
					"time":    lib.AppTime,
					"name":    lib.AppName,
					"url":     lib.ProjectURL,
				},
			},
		})
	}
}

func (ws *WebServer) ReqInstall(cfgFileName string, cfg *lib.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		if !ws.InstallMode {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "install mode is off",
			})
		}
		req := InstallRequest{}
		err := c.ShouldBindJSON(&req)
		if err != nil {
			lib.Logger.Error("invalid body: ", err.Error())
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		cfg.Server = req.Server
		cfg.Logger = req.Logger
		if cfg.Server.TempDir == "" {
			cfg.Server.TempDir = filepath.Join(cfg.Server.RootDir, ".fileserver_temp")
		}
		// 如果临时目录不存在，创建临时目录
		if !lib.IsExist(cfg.Server.TempDir) {
			os.MkdirAll(cfg.Server.TempDir, 0777)
		}
		ws.RootDir = cfg.Server.RootDir
		ws.TempDir = cfg.Server.TempDir
		ws.Database = db.Database{
			FileName: cfg.Server.DatabaseFile,
		}
		err = ws.Database.Open()
		if err != nil {
			log.Println("open database failed!", err)
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "open database failed",
			})
			return
		}
		GetInstance().Database = &ws.Database
		// 创建默认用户
		adminEntry := db.UserEntry{
			Name:         req.UserName,
			Password:     req.Password,
			IsAdmin:      true,
			Enabled:      true,
			RootDir:      "/",
			ShowDotFiles: true,
		}
		err = ws.Database.AddUser(adminEntry)
		if err != nil {
			log.Println("create user failed!", err)
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "create user failed",
			})
			return
		}

		content, _ := json.MarshalIndent(cfg, "", "  ")
		os.WriteFile(cfgFileName, content, 0666)

		ws.InstallMode = false
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "success",
		})
	}
}
