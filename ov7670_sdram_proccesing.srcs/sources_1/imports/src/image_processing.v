`timescale 1ns / 1ps

module image_processing(
    input wire clk,
    input wire rst_n,
    input wire sw_grayscale,
    input wire sw_invert,
    input wire sw_threshold,
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

    // Output Multiplexer Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_out <= 16'h0000;
        end else begin
            if (sw_threshold)
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
    // Invert bitwise for RGB565
    assign pixel_out = ~pixel_in;
endmodule

// Sub-module for Thresholding (Extreme Black and White)
module thresholding(
    input wire [7:0] gray_in,
    output wire [15:0] pixel_out
);
    // Threshold set at 128 (middle of 0-255)
    assign pixel_out = (gray_in > 8'd128) ? 16'hFFFF : 16'h0000;
endmodule
