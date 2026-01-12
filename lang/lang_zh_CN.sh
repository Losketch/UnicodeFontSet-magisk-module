# ================================
# 中文语言包 (Simplified Chinese)
# ================================

# --- 通用 ---
TXT_SERVICE_START="=== 开始执行字体模块监控任务 ==="
TXT_START_MONITOR="开始监控其他字体模块的变化..."
TXT_MONITOR_DONE="字体模块监控完成"
TXT_NO_CONFLICT="  未发现其他字体模块的冲突"

TXT_LOCK_BUSY="⚠ 另一实例正在运行，跳过本次监控"
TXT_SERVICE_BUSY="⚠ 另一实例正在运行，退出本次 service 启动"

TXT_ERROR_COMMON_MISSING="错误：common_functions.sh 未找到！"
TXT_API_TOO_LOW="Android版本过低，跳过字体注入"
TXT_ERROR_API_LEVEL="错误：API 级别未设置。"

# --- 字体 XML ---
TXT_XML_NEW="检测到模块 %s 新增了字体XML文件 %s/%s。"
TXT_XML_UPDATE="检测到模块 %s 更新了字体XML文件 %s/%s，重新处理。"
TXT_XML_RECREATE="检测到模块 %s 重新创建了字体XML文件 %s/%s。"

TXT_XML_BACKUP_FAIL="  ✗ 备份失败：%s，跳过处理"
TXT_XML_COPY_FAIL="  ✗ 复制失败：%s"

TXT_XML_INJECT_OK="  ✓ 已向 %s 注入字体配置"
TXT_XML_REPLACED="已替换 %s 的 %s/%s 并重新注入字体。"

TXT_XML_FORMAT_WARN="  ⚠ 警告：%s 格式可能不正确，跳过处理。"
TXT_XML_NOT_FOUND="  ✗ 文件不存在：%s"
TXT_XML_FRAGMENT_MISSING="  ✗ 缺少字体注入配置"
TXT_XML_NONE="  未发现其他字体XML模块"

# --- 字体二进制 ---
TXT_WARN_NO_SELF_FONTS="⚠ 本模块的 system/fonts 目录下未发现字体文件，无法处理其他模块的重名字体"
TXT_BIN_NEW="检测到模块 %s 新增了重名字体二进制文件 %s/%s。"
TXT_BIN_UPDATE="检测到模块 %s 更新了重名字体二进制文件 %s/%s，重新处理。"
TXT_BIN_RECREATE="检测到模块 %s 重新创建了重名字体二进制文件 %s/%s。"

TXT_BIN_BACKUP_OK="已删除并备份：%s/%s/%s"
TXT_BIN_BACKUP_FAIL="  ✗ 备份失败：%s，跳过处理"
TXT_BIN_NONE="  未发现其他重名字体二进制模块"

# --- 安装阶段 ---
TXT_INSTALL_XML_SCAN="正在处理其他模块的字体XML文件..."
TXT_INSTALL_BIN_SCAN="正在处理其他模块的字体二进制文件..."
TXT_INSTALL_SYSTEM_XML="正在扫描系统字体XML文件..."
TXT_INSTALL_DONE="- 安装完成,已清理冲突的字体文件"
TXT_INSTALL_PROCESS="  处理: %s/%s"
TXT_INSTALL_COPY_FAIL=" ✗ 复制失败：%s"
TXT_SYSTEM_XML_NONE="  未发现系统字体XML文件"

# --- 模块生命周期 ---
TXT_MODULE_FOUND="  发现模块: %s"
TXT_MODULE_REMOVED_XML="模块 %s 已被删除，清理相关字体XML备份 (%s)。"
TXT_MODULE_REMOVED_BIN="模块 %s 已被删除，清理相关字体二进制备份 (%s)。"

# --- 输入检测 ---
TXT_KEYCHECK_DETECT="- 使用 keycheck 检测音量键（%s 秒）"
TXT_GETEVENT_DETECT="- 使用 getevent 检测音量键（%s 秒）"
TXT_NO_INPUT_METHOD="- 未检测到可用的输入方式"

# --- cmap 清理 ---
TXT_CMAP_TITLE="📌 可选操作：cmap 字符表清理"
TXT_CMAP_DESC_1="如遇到以下问题："
TXT_CMAP_DESC_2=" - 颜文字（如 ʕ•ᴥ•ʔ、(╯°□°）、 ๑⃙⃘´༥`๑⃙⃘ 、(ͼ̤͂ ͜ ͽ̤͂)✧）显示异常"
TXT_CMAP_DESC_3=" - Emoji 显示为空白 / 方块 / 错位（如😀.png 、🤓:书呆子脸）"
TXT_CMAP_DESC_4="👉 这通常是字体 cmap 冲突导致的"
TXT_CMAP_DESC_5="⚠ 此操作会修改模块内字体文件（安全，可恢复）"

# --- Magisk ---
TXT_MAGISK_MIRROR_UNAVAIL="⚠ Magisk 镜像路径不可用，将直接使用系统路径"
TXT_MAGISK_CMD_UNAVAIL="⚠ Magisk 命令不可用，将直接使用系统路径"

TXT_CMAP_CHOICE="15 秒内："
TXT_CMAP_SKIP_HINT="  [+]音量【上】 → 跳过"
TXT_CMAP_RUN_HINT="  [-]音量【下】 → 执行清理"

TXT_CMAP_RUN="🚀 选择执行 cmap 清理"
TXT_CMAP_SKIP="↩ 用户选择跳过"
TXT_CMAP_TIMEOUT="⏱ 超时未操作，已跳过"
TXT_CMAP_UNSUPPORTED="ℹ 当前环境不支持按键检测，已跳过"

TXT_CMAP_START="🔧 执行 font-cmap-cleaner..."
TXT_CMAP_DONE="✓ font-cmap-cleaner 处理完成"
TXT_CMAP_FAIL="⚠ font-cmap-cleaner 执行失败 (exit=%s)"
TXT_CMAP_COPY_FAIL="✗ 复制 font-cmap-tool 失败"
TXT_CMAP_CANNOT_RUN="⚠ font-cmap-cleaner 无法在当前系统执行"
TXT_CMAP_TOOL_PATH="  %s"

# --- ABI / 工具 ---
TXT_ABI_PRIMARY="- 主要 ABI: %s"
TXT_ABI_LIST="- ABI 列表: %s"
TXT_ABI_UNSUPPORTED="! 不支持的 ABI: %s"
TXT_CMAP_TOOL_MISSING="! font-cmap-cleaner 二进制文件不存在或不可执行"
TXT_CMAP_TOOL_USING="- 使用 font-cmap-cleaner: %s"

# --- 锁 ---
TXT_LOCK_TIMEOUT="⚠ 锁获取超时（30秒），可能存在死锁或长时间运行的实例"
