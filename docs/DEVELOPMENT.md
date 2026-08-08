# 构建与测试 / Build and Test

## 发布配置

`release.toml` 是框架版本、Unicode 目标版本和 Variant API 门槛的唯一真源。仓库中的 `module/module.prop` 是 `SOURCE` 占位哨兵，不对应任何 Variant，也不可直接安装；CI/构建流程会用 `tools/python/release_metadata.py` 生成带 `buildState=built` 的最终 `module.prop` 和 update JSON。

字体来源与许可证 URL 维护在：

```text
font-source/font-sources.toml
```

构建时会把每只字体的许可文本下载为 `module/META-INF/licenses/LICENSE-<font stem>`。字体二进制允许跟随上游变化；每次构建生成 SHA-256 manifest，而不是锁定上游字体版本。

## Rust

```bash
cargo fmt --all -- --check
cargo check --workspace --all-targets --locked
cargo test --workspace --all-targets --locked
cargo clippy --workspace --all-targets --locked -- -D warnings
```

## Shell / Repository

```bash
find module tests/shell -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n

for test_script in tests/shell/*_test.sh; do bash "$test_script"; done
for test_script in tests/shell/*_test.sh; do busybox ash "$test_script"; done

python3 -m compileall -q tools/python
python3 -m unittest discover -s tests/python -p 'test_*.py'
python3 tools/python/validate_repository.py
```

CI 构建后还会运行 `validate_module.py` 并生成 Unicode coverage 报告。Coverage 缺口只产生 warning；框架元数据、API、policy、许可证审核状态和打包资产不一致会按发布场景触发相应校验失败。

## 发布

1. 修改 `release.toml` 的 `framework_version` / `version_code` / Unicode 目标（如有需要）。
2. 确保 `font-source/font-sources.toml` 中所有公开分发字体的 `license` URL 已人工核对；Versioned Release 与 Nightly Release 都会拒绝带 `REVIEW_REQUIRED` 的 manifest。
3. 创建与 `release.toml` 完全一致的 tag，例如 `v2.0.0`。
4. CI 自动生成两个模块、update JSON、coverage report、font manifest 和 GitHub Release。

带 `-alpha/-beta/-rc` 的框架版本会自动创建 prerelease；这类模块默认不绑定 Stable `releases/latest` 更新通道。Nightly 使用 rolling `nightly` Release。
