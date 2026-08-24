# macOS Storage Clearer

CLI Bash dùng để audit dung lượng macOS, giải thích nguyên nhân theo reason matrix và chỉ chạy cleanup sau khi người dùng chọn option rồi nhập approval phrase chính xác.

Script mặc định là read-only. Chạy không có tham số tương đương với `audit`.

Khi stdout/stderr gắn với terminal tương tác, audit hiển thị spinner cho từng phase dài để biết tiến trình vẫn đang chạy. Khi redirect output hoặc chạy CI, spinner tự chuyển thành status line tĩnh. Có thể chủ động tắt animation bằng:

```bash
SC_NO_ANIMATION=1 ./storage-clearer.sh audit
```

## Luồng sử dụng

```bash
chmod +x storage-clearer.sh
./storage-clearer.sh audit
./storage-clearer.sh explain all
./storage-clearer.sh reason simulator-old-runtimes
./storage-clearer.sh plan B
./storage-clearer.sh run
```

Các command `audit`, `explain` và `plan` không xoá hoặc thay đổi dữ liệu. Chỉ `run` có khả năng cleanup; command này yêu cầu terminal tương tác, hiển thị lại plan và bắt nhập approval phrase chính xác.

## Các option

### Package A — conservative

- Docker stopped containers.
- Docker images không còn được container tham chiếu.
- Docker build cache.
- Cache tái tạo được của npm, Bun, Gradle, Go, Pub, pnpm và Playwright.
- Simulator devices đã mất runtime.

### Package B — lựa chọn cho máy đã audit

Bao gồm Package A và xoá các iOS Simulator runtime cũ, luôn giữ runtime iOS có version mới nhất. Runtime được xoá bằng API chính thức `xcrun simctl runtime delete`; script không `rm` trực tiếp thư mục runtime hệ thống.

### Custom

Cho phép chọn từng action. Docker unused volumes được đánh dấu `HIGH` và yêu cầu approval phrase có thêm `INCLUDING VOLUMES`.

## Những dữ liệu luôn bị loại trừ khỏi A/B

- Docker volumes.
- Dữ liệu website/trình duyệt.
- Source và dữ liệu trong `~/Works`.
- Lịch sử Codex trong `~/.codex/sessions`.
- Photos, Mail, Messages, MobileSync và Trash.
- APFS/macOS snapshots.

Các nhóm browser, Works và Codex vẫn xuất hiện trong reason matrix để review, nhưng không có action tự động.

## Guard an toàn

- Từ chối chạy cleanup bằng `sudo` hoặc user `root`.
- Cache deletion chỉ chấp nhận danh sách đường dẫn cố định bên trong user home.
- Từ chối cache target là symlink.
- Go module/build cache được dọn bằng `go clean -modcache -cache -testcache` vì Go cố ý đặt module cache ở chế độ read-only; script không đổi permission để ép xoá.
- Revalidate UUID của Simulator runtime và danh sách Docker volume trước khi execute.
- Dùng lệnh prune chính thức của Docker; không bao giờ xoá trực tiếp `Docker.raw`.
- Ghi log execution vào `~/Library/Logs/storage-clearer/`.
- Đo free space trước và sau cleanup.

Nên đóng Xcode, Simulator và các build process trước khi chạy `run`. Docker Desktop cần đang chạy để audit và cleanup Docker. Full Disk Access cho Terminal giúp kết quả audit đầy đủ hơn.

Sau Docker prune, dung lượng bên trong VM được giải phóng ngay nhưng free space phía macOS có thể cập nhật chậm cho tới khi Docker Desktop chạy TRIM/compaction.

## Kiểm thử

```bash
./tests/test_storage_clearer.sh
```

Test chỉ kiểm tra cú pháp, package policy và allowlist guard; không chạy cleanup.
