package webserver

import (
	"fmt"
	"myfileserver/lib"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

type PackageDownloadEntry struct {
	StartTime       string `json:"start_time"`
	FinishFileCount uint64 `json:"finish_file_count"`
	TotalFileCount  uint64 `json:"total_file_count"`
	FinishWriteSize uint64 `json:"finish_write_size"`
	FinishSize      uint64 `json:"finish_size"`
	TotalSize       uint64 `json:"total_size"`
	Finished        bool   `json:"finished"`
}

func (ws *WebServer) ReqCreatePackage() gin.HandlerFunc {
	return func(c *gin.Context) {
		path, succeed := getPath(c)
		if !succeed {
			return
		}
		extName := c.Query("ext")
		loginUserInfo := getLoginUser(c)
		filePath := filepath.Join(ws.RootDir, loginUserInfo.UserEntry.RootDir, path)
		// 创建下载压缩包
		stat, err := os.Stat(filePath)
		if os.IsNotExist(err) {
			c.JSON(http.StatusNotFound, gin.H{"code": 10006, "message": "File or directory not found"})
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
			if stat.IsDir() {
				go lib.CreateZipForDir(filePath, processRW.DestFilename, processRW)
			} else {
				go lib.CreateZipForFile(filePath, processRW.DestFilename, processRW)
			}
		} else {
			fmt.Println(runtime.GOOS, processRW.DestFilename)
			if stat.IsDir() {
				go lib.CreateTarGzForDir(filePath, processRW.DestFilename, processRW)
			} else {
				go lib.CreateTarGzForFile(filePath, processRW.DestFilename, processRW)
			}
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "create package succeed!", "pid": pid})
	}
}
func (ws *WebServer) ReqQueryPackage() gin.HandlerFunc {
	return func(c *gin.Context) {
		pid := c.Query("pid")
		if pid == "" {
			c.JSON(http.StatusOK, gin.H{"code": 2009, "message": "pid invalid"})
			return
		}
		// 查询进度
		processRW, exist := GetInstance().PackageDownloads[pid]
		if !exist {
			fmt.Println("not found  ", pid)
			c.JSON(http.StatusOK, gin.H{"code": 2009, "message": "pid not found"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "query progress succeed", "data": PackageDownloadEntry{
			StartTime:       processRW.StartTime.Format(time.DateTime),
			FinishFileCount: processRW.FinishFileCount,
			TotalFileCount:  processRW.TotalFileCount,
			FinishWriteSize: processRW.FinishWriteSize,
			FinishSize:      processRW.FinishReadSize,
			TotalSize:       processRW.TotalSize,
			Finished:        processRW.Finished,
		}})
	}
}

func (ws *WebServer) ReqDeletePackage() gin.HandlerFunc {
	return func(c *gin.Context) {
		pid := c.Query("pid")
		if pid == "" {
			c.JSON(http.StatusNotFound, gin.H{"code": 2009, "message": "not found"})
			return
		}
		// 删除压缩包
		progressRW, exist := GetInstance().PackageDownloads[pid]
		if !exist {
			c.JSON(http.StatusNotFound, gin.H{"code": 2009, "message": "not found"})
			return
		}

		os.RemoveAll(progressRW.DestFilename)
		delete(GetInstance().PackageDownloads, pid)
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "delete succeed"})
	}
}

func (ws *WebServer) ReqDownloadPackage() gin.HandlerFunc {
	return func(c *gin.Context) {
		pid := c.Query("pid")
		pid = strings.Trim(pid, "/")
		if pid == "" {
			c.JSON(http.StatusNotFound, gin.H{"code": 2009, "message": "not found"})
			return
		}
		// 查询进度
		processRW, exist := GetInstance().PackageDownloads[pid]
		if !exist {
			c.JSON(http.StatusNotFound, gin.H{"code": 2009, "message": "not found"})
			return
		}
		if !processRW.Finished {
			if processRW.ProgressError != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"code": 2009, "message": processRW.ProgressError.Error()})
				return
			}
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "query progress succeed", "data": PackageDownloadEntry{
				StartTime:       processRW.StartTime.Format(time.DateTime),
				FinishFileCount: processRW.FinishFileCount,
				TotalFileCount:  processRW.TotalFileCount,
				FinishWriteSize: processRW.FinishWriteSize,
				FinishSize:      processRW.FinishReadSize,
				TotalSize:       processRW.TotalSize,
				Finished:        processRW.Finished,
			}})
			return
		}
		// 下载压缩包
		filename := filepath.Base(processRW.SrcFilename) + processRW.ExtName
		processRW.DownloadCount++
		c.FileAttachment(processRW.DestFilename, filename)
	}
}
