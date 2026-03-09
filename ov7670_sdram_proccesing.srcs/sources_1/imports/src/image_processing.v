`timescale 1ns / 1ps

module image_processing(
    input wire clk,
    input wire rst_n,
    input wire sw_grayscale,
    input wire sw_invert,
    input wire sw_threshold,
    input wire sw_sobel,
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

    // Output Multiplexer Logic (Priority: Sobel > Threshold > Inversion > Grayscale)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_out <= 16'h0000;
        end else begin
            if (sw_sobel)
                pixel_out <= sobel_pixel;
            else if (sw_threshold)
                pixel_out <= threshold_pixel;
            else if (sw_invert)
                pixel_out <= inverted_pixel;
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
    // Line Buffers to store 2 previous lines
    reg [7:0] line_buf1 [0:639];
    reg [7:0] line_buf2 [0:639];
    reg [9:0] x_cnt;

    // 3x3 Window
    reg [7:0] p11, p12, p13;
    reg [7:0] p21, p22, p23;
    reg [7:0] p31, p32, p33;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt <= 0;
            {p11, p12, p13, p21, p22, p23, p31, p32, p33} <= 0;
        end else if (rd_en) begin
            // Shift Window
            p11 <= p12; p12 <= p13;
            p21 <= p22; p22 <= p23;
            p31 <= p32; p32 <= p33;

            // Load new pixels into window
            p13 <= line_buf1[x_cnt];
            p23 <= line_buf2[x_cnt];
            p33 <= gray_in;

            // Update Line Buffers
            line_buf1[x_cnt] <= line_buf2[x_cnt];
            line_buf2[x_cnt] <= gray_in;

            // Update X counter (640 pixels per line)
            if (x_cnt == 639)
                x_cnt <= 0;
            else
                x_cnt <= x_cnt + 1'b1;
        end
    end

    // Sobel Kernels
    // Gx = [ -1 0 1 ]   Gy = [ -1 -2 -1 ]
    //      [ -2 0 2 ]        [  0  0  0 ]
    //      [ -1 0 1 ]        [  1  2  1 ]

    reg signed [10:0] Gx, Gy;
    reg [10:0] abs_Gx, abs_Gy;
    reg [10:0] G;

    always @(posedge clk) begin
        Gx <= (p13 + (p23 << 1) + p33) - (p11 + (p21 << 1) + p31);
        Gy <= (p31 + (p32 << 1) + p33) - (p11 + (p12 << 1) + p13);
        
        abs_Gx <= Gx[10] ? -Gx : Gx;
        abs_Gy <= Gy[10] ? -Gy : Gy;
        
        G <= abs_Gx + abs_Gy;
        
        // Output result (Threshold the gradient to show edges clearly)
        // If gradient > 50, show as white edge, else black
        pixel_out <= (G > 11'd50) ? 16'hFFFF : 16'h0000;
    end

endmodule
