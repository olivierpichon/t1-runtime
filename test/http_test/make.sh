gcc-4.9 -fdiagnostics-color=auto -o tcp_test -DHTTP_PARSER_STRICT=0 ../../colony-jit/src/libluajit.a ../../http-parser/http_parser.c -I../ -I../../http-parser -I../../colony-jit/src/ -std=c99 -g -pagezero_size 10000 -image_base 100000000 ../tm.c ../tm_uptime.c *.c
# cc -I. -DHTTP_PARSER_STRICT=0  -Wall -Wextra -O0 -g  -o tcp_test ../../colony-jit/src/libluajit.a ../../http-parser/http_parser.c -I../ -I../../http-parser -I../../colony-jit/src/ -g ../tm.c ../tm_uptime.c *.c