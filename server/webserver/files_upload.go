package webserver

import (
	"io"
	"myfileserver/db"
	"myfileserver/lib"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

type UploadFileEntry struct {
	StartTime    time.Time
	LastTime     time.Time
	FinishSize   uint64
	TotalSize    uint64
	Finished     bool
	FileEntry    lib.FileEntry
	TempFilePath string
	DestFilePath string
	UserEntry    db.UserEntry
}

func (ws *WebServer) ReqUploadFile() gin.HandlerFunc {
	return func(c *gin.Context) {
		path, succeed := getPath(c)
		if !succeed {
			return
		}
		loginUserInfo := getLoginUser(c)
		path = filepath.Join(ws.RootDir, loginUserInfo.UserEntry.RootDir, path)
		// 单文件上传
		file, err := c.FormFile("file")
		if err != nil {
			lib.Logger.Error("FormFile error:", err)
			c.JSON(http.StatusBadRequest, gin.H{"code": 1000, "message": "upload error"})
			return
		}

		destFilePath := filepath.Join(path, file.Filename)
		destFilePath, err = filepath.Abs(destFilePath)
		if err != nil {
			lib.Logger.Error("upload error:", err)
			c.JSON(http.StatusBadRequest, gin.H{"code": 1001, "message": "bad file path"})
			return
		}

		if err := c.SaveUploadedFile(file, destFilePath); err != nil {
			lib.Logger.Error("SaveUploadedFile error:", err)
			c.JSON(http.StatusBadRequest, gin.H{"code": 1002, "message": "upload error"})
			return
		}
		// 修改文件权限
		if err := os.Chmod(destFilePath, 0644); err != nil {
			lib.Logger.Error("Chmod error:", err)
			c.JSON(http.StatusBadRequest, gin.H{"code": 1003, "message": "upload error"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "upload success"})
	}
}

func (ws *WebServer) ReqCreateFileChunk() gin.HandlerFunc {
	return func(c *gin.Context) {
		path, exist := getPath(c)
		if !exist {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "无效路径",
			})
			return
		}
		req := lib.FileEntry{}
		err := c.ShouldBindJSON(&req)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		loginUserInfo := getLoginUser(c)
		uploadTaskId, _ := lib.GenerateRandomString(16)
		count := 32
		UploadFileEntry := &UploadFileEntry{
			StartTime:    time.Now(),
			LastTime:     time.Now(),
			FinishSize:   0,
			TotalSize:    uint64(req.Size),
			Finished:     false,
			FileEntry:    req,
			DestFilePath: filepath.Join(ws.RootDir, loginUserInfo.UserEntry.RootDir, path, req.Name),
			UserEntry:    loginUserInfo.UserEntry,
		}
		GetInstance().Lock.Lock()
		for i := 0; i < count; i++ {
			_, exist := GetInstance().UploadTask[uploadTaskId]
			if !exist {
				UploadFileEntry.TempFilePath = UploadFileEntry.DestFilePath + "." + uploadTaskId
				GetInstance().UploadTask[uploadTaskId] = UploadFileEntry
				break
			}
			uploadTaskId, _ = lib.GenerateRandomString(16)
		}
		GetInstance().Lock.Unlock()

		// 创建文件
		file, err := os.Create(UploadFileEntry.TempFilePath)
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
			UserId:   loginUserInfo.UserEntry.Id,
			UserName: loginUserInfo.UserEntry.Name,
			Action:   "create_upload_task",
			Information: ws.getRequestInfo(c, map[string]string{
				"upload_task_id": uploadTaskId,
				"file_name":      req.Name,
				"file_size":      strconv.FormatInt(req.Size, 10),
			}),
			Ip: c.ClientIP(),
		})
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "创建上传任务成功",
			"data": gin.H{
				"upload_task_id": uploadTaskId,
			},
		})
	}
}

func (ws *WebServer) ReqUploadFileChunk() gin.HandlerFunc {
	return func(c *gin.Context) {
		uploadTaskId := c.Query("upload_task_id")
		//lib.Logger.Error("接收上传任务130...", uploadTaskId)
		GetInstance().Lock.Lock()
		uploadFileEntry, exist := GetInstance().UploadTask[uploadTaskId]
		GetInstance().Lock.Unlock()
		if !exist {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "上传任务不存在",
			})
			return
		}
		_position := c.Query("position")
		if _position == "" {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "position is empty",
			})
			return
		}
		position, err := strconv.ParseInt(_position, 10, 64)
		//lib.Logger.Error("接收上传任务158...", uploadTaskId, "position", position)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "position is not int",
			})
			return
		}
		file, err := os.OpenFile(uploadFileEntry.TempFilePath, os.O_WRONLY, 0666)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		defer file.Close()
		data, err := io.ReadAll(c.Request.Body)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		//lib.Logger.Error("接收上传任务158...", uploadTaskId, "position", position, "data_len", len(data))
		_, err = file.WriteAt(data, position)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		stat, err := file.Stat()
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		uploadFileEntry.FinishSize = uint64(stat.Size())
		uploadFileEntry.LastTime = time.Now()
		if uploadFileEntry.FinishSize > uploadFileEntry.TotalSize {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "上传文件大小超过限制",
			})
			return
		}
		//lib.Logger.Error("接收上传任务201...", uploadTaskId, position, uploadFileEntry.FinishSize, uploadFileEntry.TotalSize)
		if uploadFileEntry.FinishSize == uploadFileEntry.TotalSize {
			uploadFileEntry.Finished = true
			GetInstance().Lock.Lock()
			GetInstance().UploadTask[uploadTaskId] = uploadFileEntry
			GetInstance().Lock.Unlock()
			// 上传完成，移动文件
			err = os.Rename(uploadFileEntry.TempFilePath, uploadFileEntry.DestFilePath)
			if err != nil {
				lib.Logger.Error("Rename error:", err)
				c.JSON(http.StatusOK, gin.H{
					"code":    1000,
					"message": err.Error(),
				})
				return
			}
			// 修改文件权限
			if err := os.Chmod(uploadFileEntry.DestFilePath, 0644); err != nil {
				lib.Logger.Error("Chmod error:", err)
				c.JSON(http.StatusBadRequest, gin.H{"code": 1003, "message": "change file permission failed"})
				return
			}
			ws.Database.AddUserHistory(db.UserHistoryEntry{
				UserId:   uploadFileEntry.UserEntry.Id,
				UserName: uploadFileEntry.UserEntry.Name,
				Action:   "upload_task_finished",
				Information: ws.getRequestInfo(c, map[string]string{
					"upload_task_id": uploadTaskId,
					"file_name":      uploadFileEntry.FileEntry.Name,
					"file_size":      strconv.FormatInt(uploadFileEntry.FileEntry.Size, 10),
				}),
				Ip: c.ClientIP(),
			})
		}
		GetInstance().Lock.Lock()
		GetInstance().UploadTask[uploadTaskId] = uploadFileEntry
		GetInstance().Lock.Unlock()
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "上传成功",
			"data": gin.H{
				"finish_size": uploadFileEntry.FinishSize,
				"total_size":  uploadFileEntry.TotalSize,
			},
		})
	}
}
