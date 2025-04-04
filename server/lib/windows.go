//go:build windows
// +build windows

package lib

import (
	"os"
	"syscall"
	"time"
)

func filetimeToTime(ft syscall.Filetime) time.Time {
	return time.Unix(0, ft.Nanoseconds())
}

func GetFileCreateTime(fileInfo os.FileInfo) time.Time {
	return filetimeToTime(fileInfo.Sys().(*syscall.Win32FileAttributeData).CreationTime)
}

func IsHideFile(fileInfo os.FileInfo) bool {
	return (fileInfo.Sys().(*syscall.Win32FileAttributeData).FileAttributes & syscall.FILE_ATTRIBUTE_HIDDEN) != 0
}
