package lib

import (
	"crypto/rand"
	"fmt"
	"math/big"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"time"
)

func FormatSize(size int64) string {
	if size < 1024 {
		return fmt.Sprintf("%d B", size)
	} else if size < 1024*1024 {
		return fmt.Sprintf("%.2f KB", float64(size)/1024)
	} else if size < 1024*1024*1024 {
		return fmt.Sprintf("%.2f MB", float64(size)/(1024*1024))
	} else if size < 1024*1024*1024*1024 {
		return fmt.Sprintf("%.2f GB", float64(size)/(1024*1024*1024))
	} else {
		return fmt.Sprintf("%.2f TB", float64(size)/(1024*1024*1024*1024))
	}
}
func FormatDateTime(dt string) string {
	t, _ := time.Parse(time.DateTime, dt)
	return t.Format(time.DateTime)
}

type UpdateFileInfo interface {
	UpdateFileInfo(dirCount uint64, fileCount uint64, fileSize int64)
}

func CalcDir(directory string, hideDotFiles bool, update UpdateFileInfo) (uint64, uint64, int64) {
	dir, err := os.Open(directory)
	if err != nil {
		return 0, 0, 0
	}
	defer dir.Close()

	dirCount := uint64(0)
	fileCount := uint64(0)
	fileSize := int64(0)
	entries, err := dir.Readdir(-1)
	if err != nil {
		return 0, 0, 0
	}
	for _, entry := range entries {
		if hideDotFiles && IsHideFile(entry) {
			continue
		}
		if entry.IsDir() {
			dirCount++
			if update != nil {
				update.UpdateFileInfo(1, 0, 0)
			}
			d, f, s := CalcDir(filepath.Join(directory, entry.Name()), hideDotFiles, update)
			dirCount += d
			fileCount += f
			fileSize += s
		} else {
			fileCount++
			fileSize += entry.Size()
			if update != nil {
				update.UpdateFileInfo(0, 1, entry.Size())
			}
		}
	}
	return dirCount, fileCount, fileSize
}

func ListFiles(directory string, hideDotFiles bool) (FileEntrySlice, error) {
	dir, err := os.Open(directory)
	if err != nil {
		return nil, fmt.Errorf("failed to open directory: %w", err)
	}
	defer dir.Close()

	entries, err := dir.Readdir(-1)
	if err != nil {
		return nil, fmt.Errorf("failed to read directory entries: %w", err)
	}
	var dirEntries FileEntrySlice
	var fileEntries FileEntrySlice
	for _, entry := range entries {
		if hideDotFiles && IsHideFile(entry) {
			continue
		}
		fileEntry := FileEntry{
			Host:       runtime.GOOS,
			Name:       entry.Name(),
			Size:       entry.Size(),
			FileMode:   uint32(entry.Mode()),
			IsDir:      entry.Mode().IsDir(),
			CreatedAt:  GetFileCreateTime(entry).Format(time.DateTime),
			ModifiedAt: entry.ModTime().Format(time.DateTime),
		}
		if entry.IsDir() {
			dirEntries = append(dirEntries, fileEntry)
			continue
		}
		fileEntries = append(fileEntries, fileEntry)
	}
	sort.Stable(fileEntries)
	sort.Stable(dirEntries)
	fileEntries = append(dirEntries, fileEntries...)
	return fileEntries, nil
}

func GenerateRandomString(length int) (string, error) {
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

	// 创建一个 big.Int 对象，表示字符集的长度
	charsetLength := big.NewInt(int64(len(charset)))

	result := make([]byte, length)
	for i := range result {
		// 生成一个随机数，范围为 0 到 charsetLength - 1
		randomIndex, err := rand.Int(rand.Reader, charsetLength)
		if err != nil {
			return "", err
		}

		// 将随机索引转换为字符集中的字符，并添加到结果中
		result[i] = charset[randomIndex.Int64()]
	}

	return string(result), nil
}

func IsExist(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
