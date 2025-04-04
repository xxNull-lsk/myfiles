# 服务器

## 协议
### 下载文件或目录
- `http://host:port/download/file_path`
- method: `GET`
- respose  
  文件
  - HEAD: `File-Host=linux|windows|darwin`
  - HEAD: `File-IsDir=false`
  - HEAD: `File-CreatedAt=2022-06-08T16:30:45+08:00`
  - HEAD: `File-ModifiedAt=2022-06-08T16:30:45+08:00`
  - HEAD: `File-FileMode=0`
  - Body: `file内容`

  目录
  - HEAD: `File-Host=linux|windows|darwin`
  - HEAD: `File-IsDir=true`
  - HEAD: `File-CreatedAt=2022-06-08T16:30:45+08:00`
  - HEAD: `File-ModifiedAt=2022-06-08T16:30:45+08:00`
  - HEAD: `File-FileMode=0`
  - Body:
```json
[
    {
        "name": "文件名",
        "is_dir": true,
        "file_mode": 0,
        "size": 0,
        "created_at": "2022-06-08T16:30:45+08:00",
        "modified_at": "2022-06-08T16:30:45+08:00"
    }
]
```

### 获取文件或目录属性
- `http://host:port/attr/file_path`
- method: `GET`
- respose  
```json
{
    "name": "文件名",
    "is_dir": true,
    "file_mode": 0,
    "size": 0,
    "created_at": "2022-06-08T16:30:45+08:00",
    "modified_at": "2022-06-08T16:30:45+08:00"
}
```
