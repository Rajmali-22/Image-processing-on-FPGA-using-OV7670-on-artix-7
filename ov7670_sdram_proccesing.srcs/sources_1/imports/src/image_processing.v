`timescale 1ns / 1ps

module image_processing(
    input wire clk,
    input wire rst_n,
    input wire sw_grayscale,
    input wire sw_invert,
    input wire sw_threshold,
    input wire sw_sobel,
    input wire sw_h_mirror,
    input wire sw_gaussian,
    input wire rd_en,
    input wire [15:0] pixel_in, // RGB565 format
    output reg [15:0] pixel_out
);

    // RGB565 decomposition
    wire [4:0] r = pixel_in[15:11];
    wire [5:0] g = pixel_in[10:5];
    wire [4:0] b = pixel_in[4:0];

    // Expand to 8 bits
    wire [7:0] r8 = {r, r[4:2]};
    wire [7:0] g8 = {g, g[5:4]};
    wire [7:0] b8 = {b, b[4:2]};

    // Calculate grayscale (Y)
    wire [15:0] y_calc = (r8 * 8'd77) + (g8 * 8'd150) + (b8 * 8'd29);
    wire [7:0] gray8 = y_calc[15:8];
    wire [15:0] grayscale_pixel = {gray8[7:3], gray8[7:2], gray8[7:3]};

    // Instantiate Inversion Module
    wire [15:0] inverted_pixel;
    color_inversion m_inv (
        .pixel_in(pixel_in),
        .pixel_out(inverted_pixel)
    );

    // Instantiate Thresholding Module
    wire [15:0] threshold_pixel;
    thresholding m_thresh (
        .gray_in(gray8),
        .pixel_out(threshold_pixel)
    );
    
    // Instantiate Sobel Edge Detection Module
    wire [15:0] sobel_pixel;
    sobel_edge_detection m_sobel (
        .clk(clk),
        .rst_n(rst_n),
        .rd_en(rd_en),
        .gray_in(gray8),
        .pixel_out(sobel_pixel)
    );

    // Instantiate Horizontal Mirroring Module
    wire [15:0] h_mirror_pixel;
    horizontal_mirror m_hmirror (
        .clk(clk),
        .rst_n(rst_n),
        .rd_en(rd_en),
        .pixel_in(pixel_in),
        .pixel_out(h_mirror_pixel)
    );

    // Instantiate Gaussian Filter Module (applied to RGB)
    wire [15:0] gaussian_pixel;
    gaussian_filter m_gaussian (
        .clk(clk),
        .rst_n(rst_n),
        .rd_en(rd_en),
        .pixel_in(pixel_in),
        .pixel_out(gaussian_pixel)
    );

    // Output Multiplexer Logic 
    // Priority: Gaussian > Sobel > Threshold > Inversion > H-Mirror > Grayscale > Original
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_out <= 16'h0000;
        end else begin
            if (sw_gaussian)
                pixel_out <= gaussian_pixel;
            else if (sw_sobel)
                pixel_out <= sobel_pixel;
            else if (sw_threshold)
                pixel_out <= threshold_pixel;
            else if (sw_invert)
                pixel_out <= inverted_pixel;
            else if (sw_h_mirror)
                pixel_out <= h_mirror_pixel;
            else if (sw_grayscale)
                pixel_out <= grayscale_pixel;
            else
                pixel_out <= pixel_in;
        end
    end

endmodule

// Sub-module for Color Inversion
module color_inversion(
    input wire [15:0] pixel_in,
    output wire [15:0] pixel_out
);
    assign pixel_out = ~pixel_in;
endmodule

// Sub-module for Thresholding
module thresholding(
    input wire [7:0] gray_in,
    output wire [15:0] pixel_out
);
    assign pixel_out = (gray_in > 8'd128) ? 16'hFFFF : 16'h0000;
endmodule

// Sub-module for Sobel Edge Detection
module sobel_edge_detection(
    input wire clk,
    input wire rst_n,
    input wire rd_en,
    input wire [7:0] gray_in,
    output reg [15:0] pixel_out
);
    reg [7:0] line_buf1 [0:639];
    reg [7:0] line_buf2 [0:639];
    reg [9:0] x_cnt;
    reg [7:0] p11, p12, p13, p21, p22, p23, p31, p32, p33;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt <= 0;
            {p11, p12, p13, p21, p22, p23, p31, p32, p33} <= 0;
        end else if (rd_en) begin
            p11 <= p12; p12 <= p13;
            p21 <= p22; p22 <= p23;
            p31 <= p32; p32 <= p33;
            p13 <= line_buf1[x_cnt];
            p23 <= line_buf2[x_cnt];
            p33 <= gray_in;
            line_buf1[x_cnt] <= line_buf2[x_cnt];
            line_buf2[x_cnt] <= gray_in;
            x_cnt <= (x_cnt == 639) ? 0 : x_cnt + 1'b1;
        end
    end

    reg signed [10:0] Gx, Gy;
    reg [10:0] abs_Gx, abs_Gy, G;

    always @(posedge clk) begin
        Gx <= (p13 + (p23 << 1) + p33) - (p11 + (p21 << 1) + p31);
        Gy <= (p31 + (p32 << 1) + p33) - (p11 + (p12 << 1) + p13);
        abs_Gx <= Gx[10] ? -Gx : Gx;
        abs_Gy <= Gy[10] ? -Gy : Gy;
        G <= abs_Gx + abs_Gy;
        pixel_out <= (G > 11'd50) ? 16'hFFFF : 16'h0000;
    end
endmodule

// Sub-module for Horizontal Mirroring (Reverses a line)
module horizontal_mirror(
    input wire clk,
    input wire rst_n,
    input wire rd_en,
    input wire [15:0] pixel_in,
    output reg [15:0] pixel_out
);
    reg [15:0] ram [0:639];
    reg [9:0] x_cnt;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt <= 0;
        end else if (rd_en) begin
            ram[x_cnt] <= pixel_in;
            pixel_out <= ram[639 - x_cnt]; // Read in reverse
            x_cnt <= (x_cnt == 639) ? 0 : x_cnt + 1'b1;
        end
    end
endmodule

// Sub-module for Gaussian Filter (3x3 Smoothing)
module gaussian_filter(
    input wire clk,
    input wire rst_n,
    input wire rd_en,
    input wire [15:0] pixel_in,
    output reg [15:0] pixel_out
);
    // Line buffers for RGB
    reg [15:0] lb1 [0:639], lb2 [0:639];
    reg [9:0] x_cnt;
    reg [15:0] p11, p12, p13, p21, p22, p23, p31, p32, p33;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt <= 0;
        end else if (rd_en) begin
            p11 <= p12; p12 <= p13;
            p21 <= p22; p22 <= p23;
            p31 <= p32; p32 <= p33;
            p13 <= lb1[x_cnt];
            p23 <= lb2[x_cnt];
            p33 <= pixel_in;
            lb1[x_cnt] <= lb2[x_cnt];
            lb2[x_cnt] <= pixel_in;
            x_cnt <= (x_cnt == 639) ? 0 : x_cnt + 1'b1;
        end
    end

    // Gaussian Kernel: [1 2 1; 2 4 2; 1 2 1] / 16
    wire [4:0] r11=p11[15:11], r12=p12[15:11], r13=p13[15:11], r21=p21[15:11], r22=p22[15:11], r23=p23[15:11], r31=p31[15:11], r32=p32[15:11], r33=p33[15:11];
    wire [5:0] g11=p11[10:5],  g12=p12[10:5],  g13=p13[10:5],  g21=p21[10:5],  g22=p22[10:5],  g23=p23[10:5],  g31=p31[10:5],  g32=p32[10:5],  g33=p33[10:5];
    wire [4:0] b11=p11[4:0],   b12=p12[4:0],   b13=p13[4:0],   b21=p21[4:0],   b22=p22[4:0],   b23=p23[4:0],   b31=p31[4:0],   b32=p32[4:0],   b33=p33[4:0];

    wire [10:0] r_sum = (r11 + (r12<<1) + r13) + ((r21<<1) + (r22<<2) + (r23<<1)) + (r31 + (r32<<1) + r33);
    wire [11:0] g_sum = (g11 + (g12<<1) + g13) + ((g21<<1) + (g22<<2) + (g23<<1)) + (g31 + (g32<<1) + g33);
    wire [10:0] b_sum = (b11 + (b12<<1) + b13) + ((b21<<1) + (b22<<2) + (b23<<1)) + (b31 + (b32<<1) + b33);

    always @(posedge clk) begin
        pixel_out <= {r_sum[8:4], g_sum[9:4], b_sum[8:4]};
    end
endmodule
