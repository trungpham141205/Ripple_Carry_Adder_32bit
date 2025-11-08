module tbRippleCarryAdder32bit();

    parameter SIZE = 32;
    parameter LOOP_LIMIT = 1000; 
    
    reg [SIZE - 1:0] a, b;
    reg cin;
    wire [SIZE - 1:0] sum;
    wire cout;

    integer i, total_tests, pass_count, fail_count;
    reg [SIZE:0]expected_sum;

    rippleCarryAdder32bit dut(
        .a(a),
        .b(b),
        .cin(cin),
        .sum(sum),
        .cout(cout)
    );

    initial begin
        total_tests = 0;
        pass_count = 0;
        fail_count = 0;
        $display("Total test | A B CIN | COUT SUM | EXPECTED | RESULT");

        for(i = 0; i < LOOP_LIMIT; i = i + 1) begin
            a = $random;
            b = $random;
            cin = $random % 2;
            #1; expected_sum = a + b + cin;
            #1; total_tests = total_tests + 1;
            if({cout, sum} === expected_sum) begin
                pass_count = pass_count + 1;
                $display("%d    | %b %b %b | %b %b | %b | PASS", total_tests, a, b, cin, cout, sum, expected_sum);
            end
            else begin
                fail_count = fail_count + 1;
                $display("%d    | %b %b %b | %b %b | %b | FAIL", total_tests, a, b, cin, cout, sum, expected_sum);
            end
            #5;
        end
        $display("----------------------------------------------------------");

        $display("Total tests: %0d | Passed: %0d | Failed: %0d", total_tests, pass_count, fail_count);
        
        $display("----------------------------------------------------------");

        if (fail_count == 0)
            $display("ALL TESTS PASSED SUCCESSFULLY!");
        else
            $display("SOME TESTS FAILED. PLEASE CHECK LOG ABOVE.");
        $finish;
    end

endmodule