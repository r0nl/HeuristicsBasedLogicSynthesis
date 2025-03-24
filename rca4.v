module rca4 (a0, a1, a2, a3, b0, b1, b2, b3, cin, s0, s1, s2, s3, cout);
  input a0, a1, a2, a3, b0, b1, b2, b3, cin;
  output s0, s1, s2, s3, cout;
  wire c0, c1, c2;
  
  fulladder F0 (.a(a0), .b(b0), .cin(cin), .sum(s0), .cout(c0));
  fulladder F1 (.a(a1), .b(b1), .cin(c0), .sum(s1), .cout(c1));
  fulladder F2 (.a(a2), .b(b2), .cin(c1), .sum(s2), .cout(c2));
  fulladder F3 (.a(a3), .b(b3), .cin(c2), .sum(s3), .cout(cout));
endmodule

module fulladder (a, b, cin, sum, cout);
  input a, b, cin;
  output sum, cout;
  wire s1, c1, c2;
  
  halfadder H1 (.a(a), .b(b), .sum(s1), .cout(c1));
  halfadder H2 (.a(cin), .b(s1), .sum(sum), .cout(c2));
  or (cout, c1, c2);
endmodule

module halfadder (a, b, sum, cout);
  input a, b;
  output sum, cout;
  
  xor (sum, a, b);
  and (cout, a, b);
endmodule



