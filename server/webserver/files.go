package webserver

import (
	"encoding/base64"
	"io"
	"myfileserver/lib"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

func getLoginUser(c *gin.Context) UserInfo {

	userSessionId := c.GetHeader("session-id")
	if userSessionId == "" {
		userSessionId, _ = c.Cookie("session-id")
	}
	if userSessionId == "" {
		userSessionId = c.Query("session-id")
	}

	GetInstance().Lock.Lock()
	userInfo := GetInstance().Tokens[userSessionId]
	GetInstance().Lock.Unlock()
	return userInfo
}

func getPath(c *gin.Context) (string, bool) {
	path := c.Query("path")
	if strings.Contains(path, "..") {
		c.JSON(http.StatusBadRequest, gin.H{"code": 1000, "message": "Invalid path"})
		return "", false
	}
	ret := ""
	for _, v := range strings.Split(path, "/") {
		if v == "" {
			continue
		}
		ret += "/" + v
	}
	if ret == "/" {
		return "", true
	}
	return ret, true
}

func (ws *WebServer) ReqDeleteFile() gin.HandlerFunc {
	return func(c *gin.Context) {
		path, succeed := getPath(c)
		if !succeed {
			return
		}
		loginUserInfo := getLoginUser(c)
		filePath := filepath.Join(ws.RootDir, loginUserInfo.UserEntry.RootDir, path)
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			c.JSON(http.StatusNotFound, gin.H{"code": 10006, "message": "File or directory not found"})
			return
		}
		err := os.RemoveAll(filePath)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"code": 10006, "message": "delete failed!"})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "delete succeed",
		})
	}
}

func CopyFile(src, dst string) error {
	srcFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer srcFile.Close()
	dstFile, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer dstFile.Close()
	_, err = io.Copy(dstFile, srcFile)
	if err != nil {
		return err
	}
	return nil
}

func (ws *WebServer) ReqChangeFile() gin.HandlerFunc {
	return func(c *gin.Context) {
		path, succeed := getPath(c)
		if !succeed {
			return
		}
		loginUserInfo := getLoginUser(c)
		filePath := filepath.Join(ws.RootDir, loginUserInfo.UserEntry.RootDir, path)
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			c.JSON(http.StatusNotFound, gin.H{"code": 1001, "message": "File or directory not found"})
			return
		}

		action := c.Query("action")
		switch action {
		case "rename":
			newName := c.Query("name")
			if newName == "" {
				c.JSON(http.StatusBadRequest, gin.H{"code": 1001, "message": "newName is empty"})
				return
			}
			newPath := filepath.Join(filepath.Dir(filePath), newName)
			err := os.Rename(filePath, newPath)
			if err != nil {
				lib.Logger.Error("Rename failed!", err)
				c.JSON(http.StatusInternalServerError, gin.H{"code": 1001, "message": "Failed to rename file"})
				return
			}
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "Rename successful"})
		case "move":
			dstPath := c.Query("dest")
			if dstPath == "" {
				c.JSON(http.StatusBadRequest, gin.H{"code": 1001, "message": "dstPath is empty"})
				return
			}
			dstPath = filepath.Join(ws.RootDir, loginUserInfo.UserEntry.RootDir, dstPath)
			if _, err := os.Stat(dstPath); os.IsExist(err) {
				c.JSON(http.StatusNotFound, gin.H{"code": 1001, "message": "dstPath is exist"})
				return
			}
			err := os.Rename(filePath, dstPath)
			if err != nil {
				lib.Logger.Error("Rename failed!", err)
				c.JSON(http.StatusInternalServerError, gin.H{"code": 1001, "message": "Failed to move file"})
				return
			}
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "Move successful"})
		case "copy":
			dstPath := c.Query("dest")
			if dstPath == "" {
				c.JSON(http.StatusBadRequest, gin.H{"code": 1001, "message": "dstPath is empty"})
				return
			}
			dstPath = filepath.Join(ws.RootDir, loginUserInfo.UserEntry.RootDir, dstPath)
			if _, err := os.Stat(dstPath); os.IsExist(err) {
				c.JSON(http.StatusNotFound, gin.H{"code": 1001, "message": "dstPath is exist"})
				return
			}
			err := CopyFile(filePath, dstPath)
			if err != nil {
				lib.Logger.Error("CopyFile failed!", err)
				c.JSON(http.StatusInternalServerError, gin.H{"code": 1001, "message": "Failed to copy file"})
				return
			}
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "Move successful"})
		case "create": // 创建文件
			if _, err := os.Stat(filePath); os.IsExist(err) {
				c.JSON(http.StatusNotFound, gin.H{"code": 1001, "message": "file is exist"})
				return
			}
			name := c.Query("name")
			if name == "" {
				c.JSON(http.StatusBadRequest, gin.H{"code": 1001, "message": "name is empty"})
				return
			}
			filePath := filepath.Join(filePath, name)
			_, err := os.Create(filePath)
			if err != nil {
				lib.Logger.Error("Create failed!", err)
				c.JSON(http.StatusInternalServerError, gin.H{"code": 1001, "message": "Failed to create file"})
				return
			}
			// 修改文件权限
			if err := os.Chmod(filePath, 0644); err != nil {
				lib.Logger.Error("Chmod error:", err)
				c.JSON(http.StatusBadRequest, gin.H{"code": 1003, "message": "change file permission failed"})
				return
			}
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "Create successful"})
		default:
			c.JSON(http.StatusBadRequest, gin.H{"code": 1001, "message": "Invalid action"})
		}

	}
}

func (ws *WebServer) ReqGetFile() gin.HandlerFunc {
	return func(c *gin.Context) {
		path, succeed := getPath(c)
		if !succeed {
			return
		}
		loginUserInfo := getLoginUser(c)
		filePath := filepath.Join(ws.RootDir, loginUserInfo.UserEntry.RootDir, path)
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			c.JSON(http.StatusNotFound, gin.H{"code": 1001, "message": "File or directory not found"})
			return
		}
		info, _ := os.Stat(filePath)
		c.Header("File-Host", runtime.GOOS)
		c.Header("File-Mode", info.Mode().String())
		c.Header("File-ModifiedAt", lib.GetFileCreateTime(info).Format(time.DateTime))
		c.Header("File-CreatedAt", info.ModTime().Format(time.DateTime))
		if info.IsDir() {
			c.Header("File-IsDir", "true")
			files, err := lib.ListFiles(filePath, !loginUserInfo.UserEntry.ShowDotFiles)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"code": 1001, "message": "Failed to open directory"})
				return
			}
			c.JSON(http.StatusOK, gin.H{
				"code":    0,
				"message": "ok",
				"files":   files,
			})
			return
		} else {
			c.Header("File-IsDir", "false")
			c.FileAttachment(filePath, filepath.Base(path))
		}
	}
}

func (ws *WebServer) ReqGetFileContent() gin.HandlerFunc {
	return func(c *gin.Context) {
		path, succeed := getPath(c)
		if !succeed {
			return
		}
		loginUserInfo := getLoginUser(c)
		filePath := filepath.Join(ws.RootDir, loginUserInfo.UserEntry.RootDir, path)
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			c.JSON(http.StatusNotFound, gin.H{"code": 1001, "message": "File or directory not found"})
			return
		}
		info, _ := os.Stat(filePath)
		if info.IsDir() {
			files, err := lib.ListFiles(filePath, !loginUserInfo.UserEntry.ShowDotFiles)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"code": 1001, "message": "Failed to open directory"})
				return
			}
			c.JSON(http.StatusOK, gin.H{
				"code":    0,
				"message": "ok",
				"files":   files,
			})
			return
		} else {
			content, err := os.ReadFile(filePath)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"code": 1001, "message": "Failed to read file"})
				return
			}
			encodeString := base64.StdEncoding.EncodeToString(content)
			c.JSON(http.StatusOK, gin.H{
				"code":    0,
				"message": "ok",
				"content": encodeString,
			})
			return
		}
	}
}

func (ws *WebServer) ReqGetAttribute() gin.HandlerFunc {
	return func(c *gin.Context) {
		path, succeed := getPath(c)
		if !succeed {
			return
		}
		loginUserInfo := getLoginUser(c)
		filePath := filepath.Join(ws.RootDir, loginUserInfo.UserEntry.RootDir, path)

		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			c.JSON(http.StatusNotFound, gin.H{"code": 404, "message": "File or directory not found"})
			return
		}

		dataRecursion, _ := c.GetQuery("recursion")
		withData := c.DefaultQuery("with_data", "0")
		info, _ := os.Stat(filePath)
		fileEntry := lib.FileDirEntryInfo{
			BaseInfo: lib.FileEntry{
				Host:       runtime.GOOS,
				Name:       info.Name(),
				Size:       info.Size(),
				FileMode:   uint32(info.Mode()),
				IsDir:      info.IsDir(),
				CreatedAt:  lib.GetFileCreateTime(info).Format(time.DateTime),
				ModifiedAt: info.ModTime().Format(time.DateTime),
			},
			FileCount: 0,
			DirCount:  0,
		}
		if dataRecursion == "1" && info.IsDir() {
			fileEntry.DirCount, fileEntry.FileCount, fileEntry.BaseInfo.Size = lib.CalcDir(filePath, !loginUserInfo.UserEntry.ShowDotFiles, nil)
		}
		if info.IsDir() {
			fileEntry.DirCount++
		} else {
			fileEntry.FileCount++
		}
		if withData == "1" {
			c.JSON(http.StatusOK, gin.H{
				"code":    0,
				"message": "ok",
				"data":    fileEntry,
			})
		} else {
			c.JSON(http.StatusOK, fileEntry)
		}
	}
}

func (ws *WebServer) ReqCreateFolder() gin.HandlerFunc {
	return func(c *gin.Context) {
		path, succeed := getPath(c)
		if !succeed {
			return
		}
		loginUserInfo := getLoginUser(c)
		err := os.MkdirAll(filepath.Join(ws.RootDir, loginUserInfo.UserEntry.RootDir, path), 0777)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"code": 2009, "message": "create folder failed"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "create folder succeed"})
	}
}

func (ws *WebServer) ReqReadFileData() gin.HandlerFunc {
	return func(c *gin.Context) {
		path, succeed := getPath(c)
		if !succeed {
			return
		}
		loginUserInfo := getLoginUser(c)
		filePath := filepath.Join(ws.RootDir, loginUserInfo.UserEntry.RootDir, path)
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			c.JSON(http.StatusNotFound, gin.H{"code": 1001, "message": "File or directory not found"})
			return
		}
		info, _ := os.Stat(filePath)
		if info.IsDir() {
			c.JSON(http.StatusBadRequest, gin.H{
				"code":    1000,
				"message": "bad file type",
			})
			return
		}
		offset, err := strconv.ParseInt(c.Query("offset"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"code": 1001, "message": "offset is bad"})
			return
		}
		len, err := strconv.ParseInt(c.Query("len"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"code": 1001, "message": "len is bad"})
			return
		}
		if len <= 0 {
			len = info.Size()
		}
		f, err := os.Open(filePath)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"code": 1001, "message": "Failed to open file for read"})
			return
		}
		defer f.Close()
		content := make([]byte, len)
		size, err := f.ReadAt(content, offset)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"code": 1001, "message": "Failed to read file"})
			return
		}
		if int64(size) < len {
			content = content[:size]
		}
		c.Header("Content-Length", strconv.Itoa(size))
		c.Data(http.StatusOK, "application/octet-stream", content)
	}
}

func (ws *WebServer) ReqWriteFileData() gin.HandlerFunc {
	return func(c *gin.Context) {
		path, succeed := getPath(c)
		if !succeed {
			return
		}
		loginUserInfo := getLoginUser(c)
		filePath := filepath.Join(ws.RootDir, loginUserInfo.UserEntry.RootDir, path)
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			c.JSON(http.StatusNotFound, gin.H{"code": 1001, "message": "File or directory not found"})
			return
		}
		info, _ := os.Stat(filePath)
		if info.IsDir() {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "bad file type",
			})
			return
		}
		offset, err := strconv.ParseInt(c.Query("offset"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"code": 1001, "message": "offset is bad"})
			return
		}
		f, err := os.OpenFile(filePath, os.O_WRONLY, 0644)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"code": 1001, "message": "Failed to open file for write"})
			return
		}
		defer f.Close()
		defer c.Request.Body.Close()
		content, _ := io.ReadAll(c.Request.Body)
		size, err := f.WriteAt(content, offset)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"code": 1001, "message": "Failed to write file"})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "ok",
			"length":  size,
		})
	}
}
