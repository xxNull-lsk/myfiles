package webserver

import (
	"encoding/json"
	"fmt"
	"io"
	"myfileserver/db"
	"myfileserver/lib"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

func (ws *WebServer) ReqGetSharedList() gin.HandlerFunc {
	return func(c *gin.Context) {
		loginUserInfo := getLoginUser(c)
		sharedList, err := ws.Database.GetSharedList(loginUserInfo.UserEntry.Id)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "get shared list succeed",
			"data":    sharedList,
		})
	}
}

func (ws *WebServer) ReqDeleteShared() gin.HandlerFunc {
	return func(c *gin.Context) {
		sid := c.Query("sid")
		sharedEntry, err := ws.Database.GetShared(sid)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		loginUserInfo := getLoginUser(c)
		// 判断是否有权限, 只有管理员和自己可以删除
		if loginUserInfo.UserEntry.Id != sharedEntry.UserId && !loginUserInfo.UserEntry.IsAdmin {
			c.JSON(http.StatusOK, gin.H{
				"code":    1001,
				"message": "no permission",
			})
			return
		}
		err = ws.Database.DeleteShared(sid)
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
			Action:   "delete_shared",
			Information: ws.getRequestInfo(c, map[string]string{
				"user_id":     strconv.FormatInt(sharedEntry.UserId, 10),
				"shared_name": sharedEntry.Name,
				"shared_path": sharedEntry.Path,
				"shared_sid":  sharedEntry.Sid,
			}),
			Ip: c.ClientIP(),
		})
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "delete shared succeed",
		})
	}
}

func (ws *WebServer) ReqUpdateShared() gin.HandlerFunc {
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
		sharedEntry := db.SharedEntry{}
		err = json.Unmarshal(data, &sharedEntry)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		loginUserInfo := getLoginUser(c)
		// 判断是否有权限, 只有管理员和自己可以修改
		if loginUserInfo.UserEntry.Id != sharedEntry.UserId && !loginUserInfo.UserEntry.IsAdmin {
			c.JSON(http.StatusOK, gin.H{
				"code":    1001,
				"message": "no permission",
			})
			return
		}
		err = ws.Database.UpdateShared(sharedEntry)
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
			Action:   "update_shared",
			Information: ws.getRequestInfo(c, map[string]string{
				"user_id":     strconv.FormatInt(sharedEntry.UserId, 10),
				"shared_name": sharedEntry.Name,
				"shared_path": sharedEntry.Path,
				"shared_sid":  sharedEntry.Sid,
			}),
			Ip: c.ClientIP(),
		})
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "update shared succeed",
		})
	}
}

func (ws *WebServer) ReqCreateShared() gin.HandlerFunc {
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
		sharedEntry := db.SharedEntry{}
		err = json.Unmarshal(data, &sharedEntry)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		loginUserInfo := getLoginUser(c)
		sharedEntry.UserId = loginUserInfo.UserEntry.Id
		// 生成一个随机的 sid, 直到生成的 sid 不存在为止
		for {
			sharedEntry.Sid, _ = lib.GenerateRandomString(16)
			_, err = ws.Database.GetShared(sharedEntry.Sid)
			if err != nil {
				break
			}
		}
		err = ws.Database.CreateShared(sharedEntry)
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
			Action:   "create_shared",
			Information: ws.getRequestInfo(c, map[string]string{
				"user_id":     strconv.FormatInt(sharedEntry.UserId, 10),
				"shared_name": sharedEntry.Name,
				"shared_path": sharedEntry.Path,
				"shared_sid":  sharedEntry.Sid,
			}),
			Ip: c.ClientIP(),
		})

		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "create shared succeed",
			"data":    sharedEntry,
		})
	}
}

func Safestring(s string) string {
	rs := []rune(s)

	count := len(rs)

	if count >= 3 {
		return string(rs[:count/3]) + "***" + string(rs[count*2/3:])
	} else if count >= 2 {
		return string(rs[:1]) + "***"
	} else {
		return "***"
	}
}

func (ws *WebServer) ReqGetShared() gin.HandlerFunc {
	return func(c *gin.Context) {
		sid := c.Query("sid")
		code := c.Query("code")
		sharedEntry, err := ws.Database.GetShared(sid)
		if err != nil {
			lib.Logger.Error("GetShared: get shared info failed!", err)
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		// 获取创建者信息
		createUserEntry, err := ws.Database.GetUserById(sharedEntry.UserId)
		if err != nil {
			lib.Logger.Error("GetShared: get user info failed!", err)
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return

		}
		if sharedEntry.Code != code {
			// 隐藏名字中间的一部分
			createName := Safestring(createUserEntry.Name)
			name := Safestring(sharedEntry.Name)

			c.JSON(http.StatusOK, gin.H{
				"code":    1001,
				"message": "code not match",
				"data": gin.H{
					"sid":       sid,
					"name":      name,
					"creator":   createName,
					"create_at": sharedEntry.CreatedAt,
				},
			})
			return
		}
		remain_count := -1
		if sharedEntry.MaxCount != 0 {
			remain_count = sharedEntry.MaxCount - sharedEntry.CurrentCount
		}
		remain_upload_size := int64(-1)
		if sharedEntry.MaxUploadSize != 0 {
			remain_upload_size = sharedEntry.MaxUploadSize - sharedEntry.CurrentUploadSize
		}
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "get shared succeed",
			"data": gin.H{
				"sid":                sid,
				"name":               sharedEntry.Name,
				"can_download":       sharedEntry.CanDownload,
				"can_upload":         sharedEntry.CanUpload,
				"time_limited":       sharedEntry.TimeLimied,
				"remain_count":       remain_count,
				"remain_upload_size": remain_upload_size,
				"creator":            createUserEntry.Name,
				"create_at":          sharedEntry.CreatedAt,
			},
		})
	}
}

func (ws *WebServer) ReqGetSharedFiles() gin.HandlerFunc {
	return func(c *gin.Context) {
		sid := c.Query("sid")
		path := c.Query("path")

		// 获取共享文件信息
		sharedEntry, err := ws.Database.GetShared(sid)
		if err != nil {
			lib.Logger.Error("GetShared: get shared info failed!", err)
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		userEntry, err := ws.Database.GetUserById(sharedEntry.UserId)
		if err != nil {
			lib.Logger.Error("GetShared: get user info failed!", err)
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		filePath := filepath.Join(ws.RootDir, userEntry.RootDir, sharedEntry.Path, path)
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			lib.Logger.Error("GetShared: file not exist!", err, filePath)
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File or directory not found"})
			return
		}

		info, _ := os.Stat(filePath)

		// 生成查看动作历史记录
		historyEntry := db.SharedHistoryEntry{
			Sid:    sid,
			Action: "view",
			Information: ws.getRequestInfo(c, map[string]string{
				"path_in_shared": path,
			}),
			Ip: c.ClientIP(),
		}
		err = ws.Database.AddSharedHistory(historyEntry)
		if err != nil {
			lib.Logger.Error("ReqUploadSharedFile: AddSharedHistory", err)
		}

		// 获取文件列表
		if info.IsDir() {
			files, err := lib.ListFiles(filePath, !userEntry.ShowDotFiles)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"code": 1001, "message": "Failed to open directory"})
				return
			}
			c.JSON(http.StatusOK, gin.H{
				"code":    0,
				"message": "ok",
				"data":    files,
			})
		} else {
			fileEntry := lib.FileEntry{
				Host:       runtime.GOOS,
				Name:       info.Name(),
				Size:       info.Size(),
				FileMode:   uint32(info.Mode()),
				IsDir:      info.IsDir(),
				CreatedAt:  lib.GetFileCreateTime(info).Format(time.DateTime),
				ModifiedAt: info.ModTime().Format(time.DateTime),
			}
			c.JSON(http.StatusOK, gin.H{
				"code":    0,
				"message": "ok",
				"data":    []lib.FileEntry{fileEntry},
			})
		}
	}
}
func (ws *WebServer) ReqDownloadSharedFile() gin.HandlerFunc {
	return func(c *gin.Context) {
		sid := c.Query("sid")
		path := c.Query("path")
		// 获取共享文件信息
		sharedEntry, err := ws.Database.GetShared(sid)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		userEntry := db.UserEntry{}
		if sharedEntry.UserId == 0 {
			userEntry.RootDir = "/"
		} else {
			userEntry, err = ws.Database.GetUserById(sharedEntry.UserId)
			if err != nil {
				c.JSON(http.StatusOK, gin.H{
					"code":    1000,
					"message": err.Error(),
				})
				return
			}
		}
		filePath := filepath.Join(ws.RootDir, userEntry.RootDir, sharedEntry.Path)
		// 检查文件是否存在
		fileInfo, err := os.Stat(filePath)
		if os.IsNotExist(err) {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "Directory not found"})
			return
		}
		if err != nil {
			lib.Logger.Errorln("ReqDownloadSharedFile: Stat", err, "filePath:", filePath)
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": err.Error()})
			return
		}
		if fileInfo.IsDir() {
			filePath = filepath.Join(filePath, path)
		}
		fileInfo, err = os.Stat(filePath)
		if os.IsNotExist(err) {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File not found"})
			return
		}
		if err != nil {
			lib.Logger.Errorln("ReqDownloadSharedFile: Stat", err, "filePath:", filePath)
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": err.Error()})
			return
		}
		// 检查文件是否可下载
		if !sharedEntry.CanDownload {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File not downloadable"})
			return
		}
		// 检查文件是否已过期
		if sharedEntry.TimeLimied > 0 {
			now := time.Now()
			createdAt, err := time.Parse(time.DateTime, sharedEntry.CreatedAt)
			if err != nil {
				c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File not downloadable"})
				return
			}
			if now.Sub(createdAt) > time.Duration(sharedEntry.TimeLimied)*time.Hour*24 {
				c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File not downloadable"})
				return
			}
		}
		// 检查文件是否已达到最大下载次数
		if sharedEntry.MaxCount > 0 {
			if sharedEntry.CurrentCount >= sharedEntry.MaxCount {
				c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File not downloadable"})
				return
			}
		}
		sharedEntry.CurrentCount++
		lib.Logger.Error("download file success", sharedEntry.CurrentCount, filePath)
		err = ws.Database.UpdateShared(sharedEntry)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File not downloadable"})
			return
		}

		// 生成下载动作历史记录
		historyEntry := db.SharedHistoryEntry{
			Sid:    sid,
			Action: "download",
			Information: ws.getRequestInfo(c, map[string]string{
				"path_in_shared": path,
				"file_size":      strconv.FormatInt(fileInfo.Size(), 10),
				"download_type":  "file",
			}),
			Ip: c.ClientIP(),
		}
		err = ws.Database.AddSharedHistory(historyEntry)
		if err != nil {
			lib.Logger.Error("ReqUploadSharedFile: AddSharedHistory", err)
		}
		// 下载文件
		c.FileAttachment(filePath, filepath.Base(filePath))

	}
}

func (ws *WebServer) ReqCreateSharedFileChunk() gin.HandlerFunc {
	return func(c *gin.Context) {
		sid := c.Query("sid")
		path, exist := getPath(c)
		if !exist {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "无效路径",
			})
			return
		}
		// 获取共享文件信息
		sharedEntry, err := ws.Database.GetShared(sid)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		userEntry := db.UserEntry{}
		if sharedEntry.UserId == 0 {
			userEntry.RootDir = "/"
		} else {
			userEntry, err = ws.Database.GetUserById(sharedEntry.UserId)
			if err != nil {
				c.JSON(http.StatusOK, gin.H{
					"code":    1000,
					"message": err.Error(),
				})
				return
			}
		}
		filePath := filepath.Join(ws.RootDir, userEntry.RootDir, sharedEntry.Path, path)
		// 检查文件是否存在
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File or directory not found"})
			return
		}
		// 检查文件是否可上传
		if !sharedEntry.CanUpload {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File not uploadable"})
			return
		}
		// 检查文件是否已过期
		if sharedEntry.TimeLimied > 0 {
			now := time.Now()
			createdAt, err := time.Parse(time.DateTime, sharedEntry.CreatedAt)
			if err != nil {
				c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File not uploadable, expired"})
				return
			}
			if now.Sub(createdAt) > time.Duration(sharedEntry.TimeLimied)*time.Hour*24 {
				c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File not uploadable, expired"})
				return
			}
		}

		req := lib.FileEntry{}
		err = c.ShouldBindJSON(&req)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		uploadTaskId, _ := lib.GenerateRandomString(16)
		count := 32
		uploadFileEntry := &UploadFileEntry{
			StartTime:    time.Now(),
			LastTime:     time.Now(),
			FinishSize:   0,
			TotalSize:    uint64(req.Size),
			Finished:     false,
			FileEntry:    req,
			DestFilePath: filepath.Join(filePath, req.Name),
			UserEntry:    userEntry,
		}
		GetInstance().Lock.Lock()
		for i := 0; i < count; i++ {
			_, exist := GetInstance().UploadTask[uploadTaskId]
			if !exist {
				uploadFileEntry.TempFilePath = filepath.Join(ws.TempDir, req.Name+"."+uploadTaskId)
				GetInstance().UploadTask[uploadTaskId] = uploadFileEntry
				break
			}
			uploadTaskId, _ = lib.GenerateRandomString(16)
		}
		GetInstance().Lock.Unlock()

		// 创建文件
		file, err := os.Create(uploadFileEntry.TempFilePath)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		file.Close()
		lib.Logger.Error("创建上传任务成功", uploadTaskId)
		ws.Database.AddUserHistory(db.UserHistoryEntry{
			UserId:   uploadFileEntry.UserEntry.Id,
			UserName: uploadFileEntry.UserEntry.Name,
			Action:   "create_shared_upload_task",
			Information: ws.getRequestInfo(c, map[string]string{
				"path_in_shared": path,
				"upload_task_id": uploadTaskId,
				"file_name":      uploadFileEntry.FileEntry.Name,
				"file_size":      strconv.FormatInt(uploadFileEntry.FileEntry.Size, 10),
			}),
			Ip: c.ClientIP(),
		})
		// 生成上传动作历史记录
		err = ws.Database.AddSharedHistory(db.SharedHistoryEntry{
			Sid:    sid,
			Action: "upload",
			Information: ws.getRequestInfo(c, map[string]string{
				"path_in_shared": path,
				"upload_task_id": uploadTaskId,
				"file_name":      uploadFileEntry.FileEntry.Name,
				"file_size":      strconv.FormatInt(uploadFileEntry.FileEntry.Size, 10),
			}),
			Ip: c.ClientIP(),
		})
		if err != nil {
			lib.Logger.Error("ReqUploadSharedFile: AddSharedHistory", err)
		}
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "创建上传任务成功",
			"data": gin.H{
				"upload_task_id": uploadTaskId,
			},
		})
	}
}

func (ws *WebServer) ReqUploadSharedFile() gin.HandlerFunc {
	return func(c *gin.Context) {
		sid := c.Query("sid")
		path := c.Query("path")
		// 获取共享文件信息
		sharedEntry, err := ws.Database.GetShared(sid)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		userEntry, err := ws.getUserEntryByID(sharedEntry.UserId)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		filePath := filepath.Join(ws.RootDir, userEntry.RootDir, sharedEntry.Path, path)
		// 检查文件是否存在
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File or directory not found"})
			return
		}
		// 检查文件是否可上传
		if !sharedEntry.CanUpload {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File not uploadable"})
			return
		}
		// 检查文件是否已过期
		if sharedEntry.TimeLimied > 0 {
			now := time.Now()
			createdAt, err := time.Parse(time.DateTime, sharedEntry.CreatedAt)
			if err != nil {
				c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File not uploadable, expired"})
				return
			}
			if now.Sub(createdAt) > time.Duration(sharedEntry.TimeLimied)*time.Hour*24 {
				c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File not uploadable, expired"})
				return
			}
		}
		// 单文件上传
		file, err := c.FormFile("file")
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"code": 1001, "message": "upload error"})
			return
		}

		if sharedEntry.MaxUploadSize > 0 {
			if sharedEntry.CurrentUploadSize+file.Size > sharedEntry.MaxUploadSize {
				c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File not uploadable, over size"})
				return
			}
		}

		destFilePath := filepath.Join(filePath, file.Filename)
		destFilePath, err = filepath.Abs(destFilePath)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"code": 1001, "message": "bad file path"})
			return
		}
		lib.Logger.Infow("ReqUploadSharedFile: upload file", destFilePath)
		if err := c.SaveUploadedFile(file, destFilePath); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"code": 1001, "message": "upload error"})
			return
		}
		lib.Logger.Infow("ReqUploadSharedFile: upload file success", destFilePath, sharedEntry.CurrentUploadSize, file.Size)
		sharedEntry.CurrentUploadSize += file.Size
		err = ws.Database.UpdateShared(sharedEntry)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File not downloadable"})
			return
		}

		ws.Database.AddUserHistory(db.UserHistoryEntry{
			UserId:   userEntry.Id,
			UserName: userEntry.Name,
			Action:   "create_shared_upload_task",
			Information: ws.getRequestInfo(c, map[string]string{
				"path_in_shared": path,
				"file_name":      file.Filename,
				"file_size":      strconv.FormatInt(file.Size, 10),
			}),
			Ip: c.ClientIP(),
		})

		// 生成上传动作历史记录
		err = ws.Database.AddSharedHistory(db.SharedHistoryEntry{
			Sid:    sid,
			Action: "upload",
			Information: ws.getRequestInfo(c, map[string]string{
				"path_in_shared": path,
				"file_name":      file.Filename,
				"file_size":      strconv.FormatInt(file.Size, 10),
			}),
			Ip: c.ClientIP(),
		})
		if err != nil {
			lib.Logger.Error("ReqUploadSharedFile: AddSharedHistory", err)
		}

		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "upload success"})
	}
}

func (ws *WebServer) ReqCreateSharedPackage() gin.HandlerFunc {
	return func(c *gin.Context) {
		sid := c.Query("sid")
		path := c.Query("path")
		extName := c.Query("ext")
		// 获取共享文件信息
		sharedEntry, err := ws.Database.GetShared(sid)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		// 检查文件是否可下载
		if !sharedEntry.CanDownload {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File not downloadable"})
			return
		}
		// 检查文件是否已达到最大下载次数
		if sharedEntry.MaxCount > 0 {
			if sharedEntry.CurrentCount >= sharedEntry.MaxCount {
				c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File not downloadable"})
				return
			}
		}
		// 检查文件是否已过期
		if sharedEntry.TimeLimied > 0 {
			now := time.Now()
			createdAt, err := time.Parse(time.DateTime, sharedEntry.CreatedAt)
			if err != nil {
				c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File not downloadable"})
				return
			}
			if now.Sub(createdAt) > time.Duration(sharedEntry.TimeLimied)*time.Hour*24 {
				c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File not downloadable"})
				return
			}
		}
		userEntry := db.UserEntry{}
		if sharedEntry.UserId == 0 {
			userEntry.RootDir = "/"
		} else {
			userEntry, err = ws.Database.GetUserById(sharedEntry.UserId)
			if err != nil {
				c.JSON(http.StatusOK, gin.H{
					"code":    1000,
					"message": err.Error(),
				})
				return
			}
		}
		filePath := filepath.Join(ws.RootDir, userEntry.RootDir, sharedEntry.Path, path)
		fileInfo, err := os.Stat(filePath)
		// 检查文件是否存在
		if os.IsNotExist(err) {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File or directory not found"})
			return
		}

		pid, _ := lib.GenerateRandomString(16)
		// 创建压缩包
		// 压缩包路径
		processRW := &lib.ProgressReaderWriter{
			Pid:             pid,
			StartTime:       time.Now(),
			SrcFilename:     filePath,
			FinishReadSize:  0,
			FinishWriteSize: 0,
			TotalSize:       0,
			FinishFileCount: 0,
			TotalFileCount:  0,
			Finished:        false,
			DownloadCount:   0,
		}

		GetInstance().Lock.Lock()
		GetInstance().PackageDownloads[pid] = processRW
		GetInstance().Lock.Unlock()
		if extName == "" {
			if runtime.GOOS == "windows" {
				extName = ".zip"
			} else {
				extName = ".tar.gz"
			}
		} else if extName != ".zip" {
			extName = ".tar.gz"
		}

		processRW.DestFilename = filepath.Join(ws.TempDir, pid+extName)
		processRW.ExtName = extName

		if extName == ".zip" {
			if fileInfo.IsDir() {
				go lib.CreateZipForDir(filePath, processRW.DestFilename, processRW)
			} else {
				go lib.CreateZipForFile(filePath, processRW.DestFilename, processRW)
			}
		} else {
			fmt.Println(runtime.GOOS, processRW.DestFilename)
			if fileInfo.IsDir() {
				go lib.CreateTarGzForDir(filePath, processRW.DestFilename, processRW)
			} else {
				go lib.CreateTarGzForFile(filePath, processRW.DestFilename, processRW)
			}
		}

		// 更新共享文件下载次数信息
		sharedEntry.CurrentCount++
		err = ws.Database.UpdateShared(sharedEntry)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "File not downloadable"})
			return
		}

		// 生成下载动作历史记录
		historyEntry := db.SharedHistoryEntry{
			Sid:    sid,
			Action: "download",
			Information: ws.getRequestInfo(c, map[string]string{
				"path_in_shared": path,
				"download_type":  "package",
			}),
			Ip: c.ClientIP(),
		}
		err = ws.Database.AddSharedHistory(historyEntry)
		if err != nil {
			lib.Logger.Error("ReqUploadSharedFile: AddSharedHistory", err)
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "create package succeed!", "pid": pid})
	}
}

func (ws *WebServer) ReqGetSharedHistory() gin.HandlerFunc {
	return func(c *gin.Context) {
		sid := c.Query("sid")
		// 获取共享文件信息
		sharedEntry, err := ws.Database.GetShared(sid)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		loginUserInfo := getLoginUser(c)
		if loginUserInfo.UserEntry.Id != sharedEntry.UserId && !loginUserInfo.UserEntry.IsAdmin {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "permission denied",
			})
			return
		}
		historyEntries, err := ws.Database.GetSharedHistory(sid)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "success", "data": historyEntries})
	}
}
