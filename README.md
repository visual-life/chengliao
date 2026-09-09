# 澄聊 Chengliao

一个面向 Android 和 Windows 的跨平台即时聊天项目。客户端使用 Flutter，服务端使用 Spring Boot、WebSocket/STOMP 和 MySQL。

> 当前版本适合学习、原型验证和继续开发，尚未达到直接部署到公网的生产安全标准。

## 功能

- Android 手机端与 Windows 桌面端共用一套 Flutter 业务代码
- 根据窗口宽度自动切换手机布局和桌面三栏布局
- 文本消息的 REST 持久化与 WebSocket/STOMP 实时推送
- 图片、语音条和普通文件上传
- 好友列表、个人资料和个性签名
- WebRTC 相机/麦克风采集与 SDP/ICE 信令基础
- Flutter 桌面端、移动端交互测试

视频/语音通话目前只完成采集和信令基础。完整产品仍需补充来电、接听、挂断状态机，以及适用于公网的 TURN 服务。

## 项目结构

```text
chengliao/
├─ client/                    # Flutter 客户端
│  ├─ lib/                    # Android / Windows 共用源码
│  ├─ android/                # Android 平台工程
│  ├─ windows/                # Windows 平台工程
│  ├─ web/                    # Flutter Web 平台壳
│  └─ test/                   # 移动端与桌面端测试
├─ server/                    # Spring Boot 服务端
│  └─ src/main/               # REST、WebSocket、JPA 源码与配置
├─ docker-compose.yml         # 本地 MySQL
├─ .env.example               # 环境变量模板，不含真实密码
├─ SECURITY.md
└─ LICENSE
```

手机端和桌面端并不是两份旧代码，而是由 `client/lib/main.dart` 共享最新实现，因此本项目采用一个仓库维护。

## 环境要求

- Flutter SDK（Dart `>=3.3.0 <4.0.0`）
- Java 17
- Maven 3.9+
- Docker Desktop（用于本地 MySQL）
- Windows 桌面构建需要 Visual Studio 的 Desktop development with C++ 工作负载

## 本地启动

### 1. 配置并启动 MySQL

在项目根目录执行：

```powershell
Copy-Item .env.example .env
```

编辑 `.env`，为 `MYSQL_PASSWORD` 和 `MYSQL_ROOT_PASSWORD` 设置两个强且不同的本地密码。真实 `.env` 已被 Git 忽略，不会上传。

```powershell
docker compose up -d --wait mysql
```

MySQL 映射到 `localhost:3307`，以避免与电脑上现有的 3306 端口冲突。

### 2. 启动服务端

在新的 PowerShell 窗口中执行，并在提示时输入 `.env` 中相同的 `MYSQL_PASSWORD`：

```powershell
Set-Location server
$env:MYSQL_PASSWORD = Read-Host "MYSQL_PASSWORD" -MaskInput
mvn spring-boot:run
```

服务端默认运行于 `http://localhost:8080`。

### 3. 启动 Flutter 客户端

Windows：

```powershell
Set-Location client
flutter pub get
flutter run -d windows
```

Android 模拟器：

```powershell
Set-Location client
flutter pub get
flutter devices
flutter run -d <device-id>
```

Windows 默认访问 `http://localhost:8080`；Android 模拟器默认访问 `http://10.0.2.2:8080`。Android 真机需要传入电脑在局域网中的地址：

```powershell
flutter run -d <device-id> --dart-define=API_BASE_URL=http://192.168.1.10:8080
```

## 测试与构建

```powershell
Set-Location client
flutter test
flutter build apk --release
flutter build windows --release
```

构建产物、APK、EXE、ZIP、用户上传文件和本地缓存均不会提交到源码仓库。发布二进制文件时请使用 GitHub Releases。

## 安全说明

仓库不包含数据库密码、API Key、签名证书、`.env`、`key.properties` 或密钥库文件。部署到公网前，请先阅读 [SECURITY.md](SECURITY.md)，并至少完成身份验证、权限控制、CORS 收紧、上传类型校验、限流、HTTPS 和 TURN 配置。

## 开源协议

本项目使用 [MIT License](LICENSE)。
