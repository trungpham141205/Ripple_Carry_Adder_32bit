module rippleCarryAdder32bit
#(parameter SIZE = 32)
(
    input wire [SIZE - 1:0] a, b,
    input wire cin,
    output wire [SIZE - 1:0]sum,
    output wire cout 
);

    wire [SIZE - 1:0] carry;

    fullAdder FA0(
        .a(a[0]),
        .b(b[0]),
        .cin(cin),
        .sum(sum[0]),
        .cout(carry[0])
    );

    genvar i;
    generate
        for(i = 1; i < SIZE; i = i + 1) begin : FA_i
            fullAdder FA(
                .a(a[i]),
                .b(b[i]),
                .cin(carry[i - 1]),
                .sum(sum[i]),
                .cout(carry[i])
            );
        end
    endgenerate

    assign cout = carry[SIZE - 1];
endmodule