# Hướng Dẫn Sử Dụng Docker cho Mô Phỏng Tiết Kiệm Năng Lượng

Container Docker này hỗ trợ cả lệnh mô phỏng và trực quan hóa MATLAB tương tác.

## Xây Dựng Container

```bash
docker build -t energy-simulation .
```

## Chạy Container

### Tùy Chọn 1: Chế Độ Tương Tác (Khuyến Nghị)

Sử dụng docker-compose:
```bash
xhost +local:docker (có thể bỏ qua)
docker-compose run energy-simulation bash
```

Khi đã vào trong container, bạn có thể chạy:
```bash
# Lệnh 1: Chạy mô phỏng với hoạt hình
./run_runSimulationWithAnimation.sh /opt/mcr/R2025a scenarios/indoor_hotspot.json

# Lệnh 2: Chạy các kịch bản chính để xuất ra file energies.txt
./run_main_run_scenarios.sh /opt/mcr/R2025a
```
### Tùy Chọn 2: Thực Thi Lệnh Trực Tiếp

Chạy các lệnh cụ thể một cách trực tiếp:

```bash
# Chạy với hỗ trợ trực quan hóa
docker run --rm \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    energy-simulation \
    ./run_runSimulationWithAnimation.sh /opt/mcr/R2025a indoor_hotspot.json

# Chạy các kịch bản chính
docker run --rm \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    energy-simulation \
    ./run_main_run_scenarios.sh /opt/mcr/R2025a
```

## Hỗ Trợ Trực Quan Hóa

Container bao gồm hỗ trợ chuyển tiếp X11 cho trực quan hóa MATLAB. Hãy đảm bảo:

1. Chạy `xhost +local:docker` trên máy chủ trước khi khởi động container
2. Sử dụng các tùy chọn `-e DISPLAY=$DISPLAY` và `-v /tmp/.X11-unix:/tmp/.X11-unix`
3. Máy của bạn phải có máy chủ X11 đang chạy