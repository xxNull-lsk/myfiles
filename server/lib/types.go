package lib

type FileEntry struct {
	Host       string `json:"host"`
	Name       string `json:"name"`
	IsDir      bool   `json:"is_dir"`
	FileMode   uint32 `json:"file_mode"`
	Size       int64  `json:"size"`
	CreatedAt  string `json:"created_at"`
	ModifiedAt string `json:"modified_at"`
}

type FileDirEntryInfo struct {
	BaseInfo  FileEntry `json:"entry"`
	FileCount uint64    `json:"file_count"`
	DirCount  uint64    `json:"dir_count"`
}
type FileEntrySlice []FileEntry

func (f FileEntrySlice) Len() int           { return len(f) }
func (f FileEntrySlice) Less(i, j int) bool { return f[i].Name < f[j].Name }
func (f FileEntrySlice) Swap(i, j int)      { f[i], f[j] = f[j], f[i] }

type ConfigLogger struct {
	Path       string `json:"path"`
	InfoFile   string `json:"info_file"`
	ErrorFile  string `json:"error_file"`
	MaxDays    int    `json:"max_days"`
	InfoLevel  int8   `json:"info_level"`
	ErrorLevel int8   `json:"error_level"`
}

type ConfigBind struct {
	Ip   string `json:"ip"`
	Port string `json:"port"`
}

type ServerConfig struct {
	RootDir      string `json:"root_dir"`
	TempDir      string `json:"temp_dir"`
	DisableWebUI bool   `json:"disable_webui"`
	DatabaseFile string `json:"database_file"`
}

type VersionConfig struct {
	AppName    string `json:"app_name" default:""`
	AppVersion string `json:"app_version" default:""`
	AppTime    string `json:"app_time" default:""`
	AppCommit  string `json:"app_commit" default:""`
	ProjectURL string `json:"project_url" default:""`
}

type Config struct {
	Bind    ConfigBind    `json:"bind"`
	Logger  ConfigLogger  `json:"logger"`
	Server  ServerConfig  `json:"server"`
	Version VersionConfig `json:"version"`
}
