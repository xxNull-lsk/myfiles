<template>
  <div class="install-wizard">
    <el-steps :active="step - 1" finish-status="success">
      <el-step title="欢迎"></el-step>
      <el-step title="配置服务器设置"></el-step>
      <el-step title="配置日志设置"></el-step>
      <el-step title="安装完成"></el-step>
    </el-steps>
    <div v-if="step === 1">
      <el-card>
        <template #header>
          <h2>步骤 1: 欢迎</h2>
        </template>
        <p>欢迎使用我们的安装向导。请点击下一步继续。</p>
        <el-button @click="nextStep">下一步</el-button>
      </el-card>
    </div>
    <div v-if="step === 2">
      <el-card>
        <template #header>
          <h2>步骤 2: 服务器参数设置</h2>
        </template>
        <el-form :model="serverSettings" ref="serverFormRef" :rules="serverRules">
          <el-form-item label="NAS根目录位置" prop="root_dir">
            <el-input v-model="serverSettings.root_dir"></el-input>
          </el-form-item>
          <el-form-item label="临时文件目录位置" prop="temp_dir">
            <el-input v-model="serverSettings.temp_dir"></el-input>
          </el-form-item>
          <el-form-item label="数据库文件的位置" prop="database_file">
            <el-input v-model="serverSettings.database_file"></el-input>
          </el-form-item>
          <el-form-item label="默认账号名" prop="user_name">
            <el-input v-model="serverSettings.user_name"></el-input>
          </el-form-item>
          <el-form-item label="账号密码" prop="password">
            <el-input v-model="serverSettings.password" type="password"></el-input>
          </el-form-item>
          <el-form-item label="确认密码" prop="confirmPassword">
            <el-input v-model="serverSettings.confirmPassword" type="password"></el-input>
          </el-form-item>
          <el-form-item label="禁用内置Web界面">
            <el-switch v-model="serverSettings.disable_webui"></el-switch>
          </el-form-item>
        </el-form>
        <el-button @click="prevStep">上一步</el-button>
        <el-button @click="submitServerForm">下一步</el-button>
      </el-card>
    </div>
    <div v-if="step === 3">
      <el-card>
        <template #header>
          <h2>步骤 3: 日志参数设置</h2>
        </template>
        <el-form :model="logSettings">
          <el-form-item label="日志路径">
            <el-input v-model="logSettings.path"></el-input>
          </el-form-item>
          <el-form-item label="最大记录天数">
            <el-input-number v-model="logSettings.max_days" :min="1" :max="365"></el-input-number>
          </el-form-item>
          <el-form-item label="info文件的日志级别">
            <el-select v-model="logSettings.info_level" placeholder="请选择日志级别">
              <el-option label="Debug" :value="-1"></el-option>
              <el-option label="Infomation" :value="0"></el-option>
              <el-option label="Warn" :value="1"></el-option>
              <el-option label="Error" :value="2"></el-option>
              <el-option label="DPanic" :value="3"></el-option>
              <el-option label="Panic" :value="4"></el-option>
              <el-option label="Fatal" :value="5"></el-option>
            </el-select>
          </el-form-item>
          <el-form-item label="error文件的日志级别">
            <el-select v-model="logSettings.error_level" placeholder="请选择日志级别">
              <el-option label="Debug" :value="-1"></el-option>
              <el-option label="Infomation" :value="0"></el-option>
              <el-option label="Warn" :value="1"></el-option>
              <el-option label="Error" :value="2"></el-option>
              <el-option label="DPanic" :value="3"></el-option>
              <el-option label="Panic" :value="4"></el-option>
              <el-option label="Fatal" :value="5"></el-option>
            </el-select>
          </el-form-item>
          <el-form-item label="info日志文件的名字">
            <el-input v-model="logSettings.info_file"></el-input>
          </el-form-item>
          <el-form-item label="error日志文件的名字">
            <el-input v-model="logSettings.error_file"></el-input>
          </el-form-item>
        </el-form>
        <el-button @click="prevStep">上一步</el-button>
        <el-button @click="nextStep">下一步</el-button>
      </el-card>
    </div>
    <div v-if="step === 4">
      <el-card>
        <template #header>
          <h2>步骤 4: 安装完成</h2>
        </template>
        <p>确认所有设置无误后，点击“安装”按钮开始安装。</p>
        <el-button @click="prevStep">上一步</el-button>
        <el-button @click="startInstall" type="primary">安装</el-button>
      </el-card>
    </div>
  </div>
  <div class="status-bar">
    <span>Powered by <a :href="serverVersion.url" target="_blank">{{ serverVersion.name }}</a> 当前版本<span
        :title=serverVersion.commit>{{ serverVersion.version }}</span>，构建于 {{ serverVersion.time }}</span>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
// 引入 api.js 中的函数
import { getServerInfo, doInstall } from '../api.js';
import { ElNotification } from 'element-plus';

// 初始化步骤为1
const step = ref(1);
// 新增日志设置
const logSettings = ref({
  path: '/var/log/myfileserver',
  max_days: 7,
  info_level: 0,
  error_level: 2,
  info_file: 'info.log',
  error_file: 'error.log'
});

// 新增服务器设置
const serverSettings = ref({
  root_dir: '/mnt/myfileserver',
  temp_dir: '/tmp/myfileserver',
  database_file: '/var/lib/myfileserver/myfileserver.db',
  user_name: 'admin',
  password: '',
  confirmPassword: '',
  disable_webui: false
});

// 自定义密码校验规则
const validatePassword = (rule, value, callback) => {
  if (value !== serverSettings.value.password) {
    callback(new Error('两次输入的密码不一致，请重新输入'));
  } else {
    callback();
  }
};

// 服务器表单验证规则
const serverRules = ref({
  root_dir: [
    { required: true, message: 'NAS根目录位置不能为空', trigger: 'blur' }
  ],
  temp_dir: [
    { required: true, message: '临时文件目录位置不能为空', trigger: 'blur' }
  ],
  database_file: [
    { required: true, message: '数据库文件的位置不能为空', trigger: 'blur' }
  ],
  user_name: [
    { required: true, message: '默认账号名不能为空', trigger: 'blur' }
  ],
  password: [
    { required: true, message: '账号密码不能为空', trigger: 'blur' }
  ],
  confirmPassword: [
    { required: true, message: '请再次输入密码', trigger: 'blur' },
    { validator: validatePassword, trigger: 'blur' }
  ]
});

const serverVersion = ref({
  name: 'MyFileServer',
  version: '1.0.0',
  commit: '123',
  time: '2025-03-30',
  url: ""
})

// 服务器表单引用
const serverFormRef = ref(null);

// 下一步函数
const nextStep = () => {
  if (step.value < 4) {
    step.value++;
  }
};

// 提交服务器表单函数
const submitServerForm = () => {
  serverFormRef.value.validate((valid) => {
    if (valid) {
      nextStep();
    } else {
      console.log('服务器表单验证失败');
    }
  });
};

// 上一步函数
const prevStep = () => {
  if (step.value > 1) {
    step.value--;
  }
};

// 开始安装函数
const startInstall = async () => {
  const result = await doInstall(logSettings.value, serverSettings.value);
  if (result.code === 0) {
    step.value = 4;
    ElNotification({
      title: '成功',
      message: '安装成功！',
      type: 'success'
    });
    // 等待 3 秒后跳转到 /
    setTimeout(() => {
      window.location.href = '/';
    }, 3000);
  } else {
    ElNotification({
      title: '错误',
      message: result.message,
      type: 'error'
    });
  }
};

// 在组件挂载时调用获取服务器信息函数
onMounted(async () => {
  const result = await getServerInfo();
  if (result.code === 0) {
    logSettings.value = result.data.logger;
    serverSettings.value = result.data.server;
    serverVersion.value = result.data.app;
  } else {
    ElNotification({
      title: '错误',
      message: result.message,
      type: 'error'
    });
  }
});
</script>

<style scoped>
.install-wizard {
  width: 90%;
  margin: 0 auto;
  padding: 20px;
}

.status-bar {
  position: fixed;
  bottom: 0;
  left: 0;
  font-size: small;
  width: 100%;
  background-color: #f0f0f0;
  padding: 10px;
  text-align: center;
  border-top: 1px solid #ccc;
}
</style>
