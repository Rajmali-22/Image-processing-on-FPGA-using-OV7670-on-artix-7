`timescale 1ns / 1ps

module image_processing(
    input wire clk,
    input wire rst_n,
    input wire sw_grayscale,
    input wire [15:0] pixel_in, // RGB565 format
    output reg [15:0] pixel_out
);

    // RGB565 decomposition
    // R: bits [15:11] (5 bits)
    // G: bits [10:5]  (6 bits)
    // B: bits [4:0]   (5 bits)
    wire [4:0] r = pixel_in[15:11];
    wire [5:0] g = pixel_in[10:5];
    wire [4:0] b = pixel_in[4:0];

    // Expand to 8 bits for higher precision calculation
    wire [7:0] r8 = {r, r[4:2]};
    wire [7:0] g8 = {g, g[5:4]};
    wire [7:0] b8 = {b, b[4:2]};

    // Calculate grayscale (Y = 0.299R + 0.587G + 0.114B)
    // Fixed point approximation: Y = (R*77 + G*150 + B*29) / 256
    wire [15:0] y_calc = (r8 * 8'd77) + (g8 * 8'd150) + (b8 * 8'd29);
    wire [7:0] gray8 = y_calc[15:8];

    // Re-pack into RGB565 (R=G=B=Gray)
    // R (5 bits), G (6 bits), B (5 bits)
    wire [15:0] grayscale_pixel = {gray8[7:3], gray8[7:2], gray8[7:3]};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_out <= 16'h0000;
        end else begin
            if (sw_grayscale)
                pixel_out <= grayscale_pixel;
            else
                pixel_out <= pixel_in;
        end
    end

endmodule
