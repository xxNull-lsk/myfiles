package main

import (
	"embed"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"myfileserver/db"
	"myfileserver/lib"
	"myfileserver/webserver"
	"net/http"
	"os"
	"path"
	"sync"
	"time"

	ginzap "github.com/gin-contrib/zap"
	"github.com/gin-gonic/gin"
)

//go:embed front/*
var efs embed.FS

func autoCleanTemp() {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()
	for range ticker.C {
		webserver.GetInstance().Lock.Lock()
		keys := make([]string, len(webserver.GetInstance().PackageDownloads))
		j := 0
		for k, progressRW := range webserver.GetInstance().PackageDownloads {
			if !progressRW.Finished {
				continue
			}

			if progressRW.DownloadCount > 0 {
				// 下载次数大于 0 时，文件保留 24 小时
				if time.Since(progressRW.StartTime) > 24*time.Hour {
					keys[j] = k
					j++
				}
			} else {
				// 下载次数等于 0 时，文件保留 1 分钟
				if time.Since(progressRW.StartTime) > 1*time.Minute {
					keys[j] = k
					j++
				}
			}
		}
		keys = keys[:j]
		for k := range keys {
			progressRW := webserver.GetInstance().PackageDownloads[keys[k]]
			log.Println("autoCleanTemp: remove package file ",
				"uploadTaskId:", k, "tempFile:",
				progressRW.DestFilename,
				"finished:", progressRW.Finished)
			os.Remove(progressRW.DestFilename)
			delete(webserver.GetInstance().PackageDownloads, keys[k])
		}

		keys = make([]string, len(webserver.GetInstance().UploadTask))
		j = 0
		for k, uploadTask := range webserver.GetInstance().UploadTask {
			if time.Since(uploadTask.LastTime) < 1*time.Minute {
				continue
			}
			keys[j] = k
			j++
		}
		keys = keys[:j]
		for k := range keys {
			uploadTask := webserver.GetInstance().UploadTask[keys[k]]
			log.Println("autoCleanTemp: remove upload file ",
				"uploadTaskId:", k,
				"tempFile:", uploadTask.TempFilePath,
				"finished:", uploadTask.Finished,
				"LastTime", uploadTask.LastTime.Format(time.DateTime),
				"StartTime", uploadTask.StartTime.Format(time.DateTime))
			os.Remove(uploadTask.TempFilePath)
			delete(webserver.GetInstance().UploadTask, keys[k])
		}
		webserver.GetInstance().Lock.Unlock()
	}
}

func GetDefaultConfig() lib.Config {
	return lib.Config{
		Bind: lib.ConfigBind{
			Ip:   "0.0.0.0",
			Port: "8080",
		},
		Logger: lib.ConfigLogger{
			Path:      "/var/log/myfileserver",
			InfoFile:  "info.log",
			ErrorFile: "err.log",
			MaxDays:   7,
			//"level_doc": "-1: debug, 0:info, 1:warn, 2:error, 3:DPanic, 4: panic, 5: fatal",
			InfoLevel:  0,
			ErrorLevel: 2,
		},
		Server: lib.ServerConfig{
			RootDir:      "",
			TempDir:      "",
			DisableWebUI: false,
		},
	}
}

func main() {
	log.Println(lib.AppName, lib.AppVersion, lib.AppTime, lib.AppCommitID)

	// 处理命令行参数
	rootDir := flag.String("dir", "", "root dir for download")
	tempDir := flag.String("temp", "", "root dir for download")
	host := flag.String("host", "", "host fot bind")
	port := flag.String("port", "", "port for download")
	debugMode := flag.Bool("debug", false, "run as debug mode")
	cfgFileName := flag.String("cfg", "myfileserver.cfg", "config file name")
	databaseFile := flag.String("db", "", "database file name")
	flag.Parse()

	var cfg lib.Config
	content, err := os.ReadFile(*cfgFileName)
	if err != nil {
		fmt.Println("Load config file failed!err:", err, "cfgFileName:", *cfgFileName)
		cfg = GetDefaultConfig()
		content, _ = json.MarshalIndent(cfg, "", "  ")
		os.WriteFile(*cfgFileName, content, 0666)
	} else {
		err = json.Unmarshal(content, &cfg)
		if err != nil {
			fmt.Println("parse config file failed!err:", err, "cfgFileName:", *cfgFileName)
			return
		}
	}

	if *rootDir != "" {
		cfg.Server.RootDir = *rootDir
	}
	if *databaseFile != "" || cfg.Server.DatabaseFile == "" {
		cfg.Server.DatabaseFile = *databaseFile
	}

	if *tempDir != "" {
		cfg.Server.TempDir = *tempDir
	}
	if *debugMode {
		gin.SetMode(gin.DebugMode)
	} else {
		gin.SetMode(gin.ReleaseMode)
	}
	if *host != "" {
		cfg.Bind.Ip = *host
	}
	if *port != "" {
		cfg.Bind.Port = *port
	}
	lib.InitLog(cfg)

	// 启动服务
	r := gin.Default()
	r.Use(ginzap.Ginzap(lib.Logger.Desugar(), "2006-01-02 15:04:05.000", false))
	r.Use(ginzap.RecoveryWithZap(lib.Logger.Desugar(), true))
	r.Use(Cors())
	ws := webserver.WebServer{}
	if cfg.Server.RootDir == "" {
		// 获取当前目录
		dir, err := os.Getwd()
		if err != nil {
			log.Println("get current dir failed!", err)
			return
		}
		cfg.Server.RootDir = dir
	}

	if cfg.Server.TempDir == "" {
		cfg.Server.TempDir = path.Join(cfg.Server.RootDir, ".fileserver_temp")
	}
	ws.RootDir = cfg.Server.RootDir
	ws.TempDir = cfg.Server.TempDir
	if cfg.Version.AppTime != "" {
		lib.AppTime = cfg.Version.AppTime
	}
	if cfg.Version.AppCommit != "" {
		lib.AppCommitID = cfg.Version.AppCommit
	}
	if cfg.Version.AppVersion != "" {
		lib.AppVersion = cfg.Version.AppVersion
	}
	if cfg.Version.AppName != "" {
		lib.AppName = cfg.Version.AppName
	}

	webserver.GetInstance().Lock = sync.Mutex{}
	webserver.GetInstance().Tokens = make(map[string]webserver.UserInfo)
	webserver.GetInstance().PackageDownloads = make(map[string]*lib.ProgressReaderWriter)
	webserver.GetInstance().UploadTask = make(map[string]*webserver.UploadFileEntry)
	if cfg.Server.RootDir == "" {
		lib.Logger.Info("RootDir is empty, enter install mode!")
		ws.InstallMode = true
		// 进入安装模式
		r.GET("/api/install", ws.ReqGetInstall(&cfg))
		r.POST("/api/install", ws.ReqInstall(*cfgFileName, &cfg))
	} else {
		lib.Logger.Info("RootDir is not empty, enter normal mode!")
		ws.InstallMode = false
		// 进入普通模式
		ws.Database = db.Database{
			FileName: cfg.Server.DatabaseFile,
		}
		err = ws.Database.Open()
		if err != nil {
			lib.Logger.Error("open database failed!", err)
			return
		}
		webserver.GetInstance().Database = &ws.Database
	}
	// 清理临时文件夹
	os.RemoveAll(ws.TempDir)
	os.MkdirAll(ws.TempDir, 0777)

	// 定时清理临时文件夹
	go autoCleanTemp()

	// 定义路由
	if !cfg.Server.DisableWebUI {
		r.GET("/", func(c *gin.Context) {
			if ws.InstallMode {
				c.Redirect(http.StatusFound, "/front/install/index.html")
				return
			}
			if cfg.Server.DisableWebUI {
				c.AbortWithStatus(http.StatusNotFound)
				return
			}
			c.Redirect(http.StatusFound, "/front/index.html")
		})
	}

	r.Use(webserver.LoggerMiddleware())

	r.GET("/api/version", ws.ReqVersion())

	r.POST("/api/logout", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqLogout())
	r.POST("/api/login", webserver.MiddlewareInstall(&ws), ws.ReqLogin())

	r.GET("/api/system", webserver.MiddlewareInstall(&ws), webserver.AuthAdminMiddleware(), ws.ReqGetSystemInformation())

	r.GET("/api/user/setting", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqGetUserSetting())
	r.POST("/api/user/setting", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqSetUserSetting())

	r.PUT("/api/user", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqUpdateUser())

	r.POST("/api/user", webserver.MiddlewareInstall(&ws), webserver.AuthAdminMiddleware(), ws.ReqCreateUser())
	r.DELETE("/api/user", webserver.MiddlewareInstall(&ws), webserver.AuthAdminMiddleware(), ws.ReqDeleteUser())
	r.GET("/api/users", webserver.MiddlewareInstall(&ws), webserver.AuthAdminMiddleware(), ws.ReqGetUserList())
	r.GET("/api/user/history", webserver.MiddlewareInstall(&ws), webserver.AuthAdminMiddleware(), ws.ReqGetUserHistory())

	r.GET("/api/file", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqGetFile())
	r.DELETE("/api/file", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqDeleteFile())
	r.POST("/api/file", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqUploadFile())
	r.GET("/api/file/content", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqGetFileContent())
	r.GET("/api/file/data", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqReadFileData())
	r.PUT("/api/file/data", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqWriteFileData())
	r.POST("/api/file/upload", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqCreateFileChunk())
	r.PUT("/api/file/upload", webserver.MiddlewareInstall(&ws), ws.ReqUploadFileChunk())
	r.PUT("/api/file", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqChangeFile())

	r.GET("/api/attribute", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqGetAttribute())

	r.POST("/api/folder", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqCreateFolder())

	r.POST("/api/pkg", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqCreatePackage())   // 开始压缩
	r.PUT("/api/pkg", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqQueryPackage())     // 查询压缩进度
	r.GET("/api/pkg", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqDownloadPackage())  // 下载压缩文件
	r.DELETE("/api/pkg", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqDeletePackage()) // 删除压缩文件

	r.PUT("/api/shared", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqUpdateShared())
	r.POST("/api/shared", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqCreateShared())
	r.DELETE("/api/shared", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqDeleteShared())
	r.GET("/api/shareds", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqGetSharedList())
	r.GET("/api/shared/history", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqGetSharedHistory())

	r.GET("/api/shared", webserver.MiddlewareInstall(&ws), ws.ReqGetShared())
	r.GET("/api/shared/files", webserver.MiddlewareInstall(&ws), webserver.AuthSharedMiddleware(), ws.ReqGetSharedFiles())
	r.GET("/api/shared/file", webserver.MiddlewareInstall(&ws), webserver.AuthSharedMiddleware(), ws.ReqDownloadSharedFile())
	r.POST("/api/shared/file", webserver.MiddlewareInstall(&ws), webserver.AuthSharedMiddleware(), ws.ReqUploadSharedFile())
	r.POST("/api/shared/upload", webserver.MiddlewareInstall(&ws), webserver.AuthSharedMiddleware(), ws.ReqCreateSharedFileChunk())

	r.POST("/api/shared/pkg", webserver.MiddlewareInstall(&ws), webserver.AuthSharedMiddleware(), ws.ReqCreateSharedPackage()) // 开始压缩
	r.PUT("/api/shared/pkg", webserver.MiddlewareInstall(&ws), webserver.AuthSharedMiddleware(), ws.ReqQueryPackage())         // 查询压缩进度
	r.GET("/api/shared/pkg", webserver.MiddlewareInstall(&ws), webserver.AuthSharedMiddleware(), ws.ReqDownloadPackage())      // 下载压缩文件
	r.DELETE("/api/shared/pkg", webserver.MiddlewareInstall(&ws), webserver.AuthSharedMiddleware(), ws.ReqDeletePackage())     // 删除压缩文件

	r.GET("/api/favorites", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqGetFavoritesList())
	r.POST("/api/favorites", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqCreateFavorites())
	r.DELETE("/api/favorites", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqDeleteFavorites())

	r.GET("/api/xterm", webserver.MiddlewareInstall(&ws), webserver.AuthMiddleware(), ws.ReqCreateXtermWebSocket())

	if !cfg.Server.DisableWebUI {
		r.NoRoute(gin.WrapH(http.FileServer(http.FS(efs))))
		if *debugMode {
			homePath, _ := os.UserHomeDir()
			r.Static("/.pub-cache", path.Join(homePath, ".pub-cache"))
		}
	}

	hostname, _ := os.Hostname()
	if cfg.Bind.Ip != "0.0.0.0" {
		hostname = cfg.Bind.Ip
	}
	lib.Logger.Info(fmt.Sprintf("%s %s %s build at %s start...", lib.AppName, lib.AppVersion, lib.AppCommitID, lib.AppTime))
	lib.Logger.Info("http://" + hostname + ":" + cfg.Bind.Port)

	r.Run(cfg.Bind.Ip + ":" + cfg.Bind.Port)
}

// Cors 跨域中间件
func Cors() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS, PUT, DELETE, UPDATE")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "*")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(200)
		}

		c.Next()
	}
}
