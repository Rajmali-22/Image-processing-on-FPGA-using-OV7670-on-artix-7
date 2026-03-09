# Image Processing on FPGA using OV7670 (Artix-7)

This project implements real-time image processing on an Artix-7 FPGA using an OV7670 camera module and VGA output. The system captures video data, stores it in SDRAM, and applies various image processing effects before displaying it on a VGA monitor.

## Features

- **Real-time Video Capture**: Interfacing with OV7670 camera (RGB565).
- **SDRAM Buffering**: High-speed memory interface for frame storage.
- **VGA Display**: 640x480 resolution output.
- **Image Processing Suite**:
  - **Grayscale Conversion**: Converts color video to black and white (Switch P8).
  - **Color Inversion**: Creates a negative effect by inverting RGB565 bits (Switch T7).
  - **Binary Thresholding**: High-contrast black and white output based on a 128-intensity threshold (Switch N6).

## Controls

| Control | Function | Pin |
|---------|----------|-----|
| **Switch P8** | Grayscale Mode | P8 |
| **Switch T7** | Color Inversion Mode | T7 |
| **Switch N6** | Thresholding Mode | N6 |
| **Key[1:0]**  | Brightness Control | K13, L13 |
| **Key[3:2]**  | Contrast Control | L14, M12 |
| **Rst_n**     | System Reset | M6 |

## Architecture

The system consists of several key modules:
- `top_module.v`: Top-level integration.
- `camera_interface.v`: OV7670 configuration (SCCB) and data retrieval.
- `sdram_interface.v`: Logic for reading/writing pixel data to SDRAM.
- `image_processing.v`: Modular processing engine containing sub-modules for each effect.
- `vga_interface.v`: VGA timing and display logic.

## Hardware Requirements

- Artix-7 FPGA Development Board.
- OV7670 Camera Module.
- VGA-compatible Monitor and Cable.
