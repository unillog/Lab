Bộ mã JIT của gSerDesQuad
==========================

Thư mục này chứa mã mà EdgeX sinh ra khi chạy thiết kế gSerDesQuad, dàn
theo ba tầng của đường ống biên dịch, cộng mã máy x86-64 cuối cùng mà
ORC JIT thực sự nạp và chạy.

Sinh lại toàn bộ bằng một lệnh:

    ./gen_jit.sh            cả ba tầng
    ./gen_jit.sh ir         chỉ MLIR edgex-dialect
    ./gen_jit.sh llvm       chỉ MLIR LLVM-dialect
    ./gen_jit.sh obj        chỉ object cache + mã máy


1. Nguồn gốc bản đang có
-------------------------

Đọc PROVENANCE.txt trước khi tin bất cứ con số nào ở đây. Bản hiện tại
sinh lúc 2026-10-16 07:52 từ một cây CHƯA SẠCH:

    commit nền   81ef727
    chưa commit  29 tệp (Đợt 7 đang thi công: file I/O, chín dạng
                 $display, N228/N229/N230)
    md5 của diff 6604cba6cf5ddf384104d590253639ab
    nhị phân     2026-10-16 07:43:22

Nghĩa là bộ mã này KHÔNG tái lập được từ một commit nào. Nó là ảnh chụp
của một cây đang thi công, giữ lại để xem xét chứ không phải để đối
chứng lâu dài. Sinh lại bản chính thức sau khi Đợt 7 đóng và commit.


2. Bốn tệp, bốn tầng
---------------------

    gserdes_quad.edgex.mlir     59.439 dòng   4,3 MB
        MLIR phương ngữ edgex, sau IMPORT và DATATYPE. Đây là chỗ ngữ
        nghĩa SystemVerilog còn nhìn thấy được: process, tín hiệu,
        kiểu 4-state, thời gian.

    gserdes_quad.llvm.mlir     515.724 dòng  24,4 MB
        MLIR phương ngữ LLVM, sau OPTIMIZE và CODEGEN. Mọi khái niệm
        SystemVerilog đã bị hạ xuống phép toán và truy cập bộ nhớ.

    jit-cache/                  210 tệp .o    1,2 MB
        Mã máy THẬT. Mỗi tệp là một ELF x86-64 relocatable chứa đúng
        MỘT hàm. Tên tệp là khoá băm của cache (xem mục 4).

    gserdes_quad.jit.asm         75.493 dòng   2,2 MB
        Tháo rời cả 210 object theo thứ tự ổn định, mỗi khối có tên
        object và tên ký hiệu ở đầu.

    gserdes_quad.jit.symbols        210 dòng
        Bảng tra: kích thước, tên ký hiệu, tệp object.


3. Đọc gì trước
----------------

Mỗi process SystemVerilog thành đúng một hàm tên
proc_<đường-dẫn-phân-cấp>. Ví dụ:

    proc_gserdes_quad_tb_u_dut_u_lane0_u_pcs_tx_10

Sáu hàm lớn nhất (byte, lấy từ gserdes_quad.jit.symbols):

    123.088   proc_gserdes_quad_tb_35
     49.839   proc_gserdes_quad_tb_31
     12.090   proc_gserdes_quad_tb_u_dut_u_lane3_u_pcs_tx_10
     12.090   proc_gserdes_quad_tb_u_dut_u_lane2_u_pcs_tx_10
     12.090   proc_gserdes_quad_tb_u_dut_u_lane1_u_pcs_tx_10
     12.090   proc_gserdes_quad_tb_u_dut_u_lane0_u_pcs_tx_10

Mã sinh ra có dùng vector rộng. Trích từ một hàm coupling:

    cmp    $0x1,%esi
    jne    d
    xor    %eax,%eax
    ...
    vmovups 0x947(%rdi),%zmm0
    vmovups %zmm0,0x88a(%rdi)
    orb    $0x1,0x2d00(%rdi)

zmm0 là thanh ghi AVX-512; ymm cũng xuất hiện nhiều trong các hàm PCS.
Trạng thái process được địa chỉ bằng offset hằng số trên %rdi.


4. Một quan sát đo được về bốn lane
------------------------------------

Bốn lane của gSerDesQuad giống hệt nhau về cấu trúc. Chúng cho ra bốn
object RIÊNG BIỆT, bốn khoá băm khác nhau, cùng kích thước 12.090 byte.

Phép đo: tháo rời lane0 và lane1, chuẩn hoá tên ký hiệu (lane0/lane1 ->
laneN) rồi chuẩn hoá mọi hằng số hex (0x... -> 0xN), sau đó so dòng:

    trước chuẩn hoá        58/3.319 dòng khác
    chuẩn hoá tên          52/3.319 dòng khác
    chuẩn hoá cả hằng số   GIỐNG HỆT, 0 dòng khác

Tức bốn lane sinh ra CÙNG MỘT dãy lệnh, chỉ khác các hằng số offset
trạng thái được nướng thẳng vào lệnh. Các dòng còn khác đều có dạng:

    movzbl 0xd4e(%rdi),%r9d        <- lane0
    movzbl 0x1338(%rdi),%r9d       <- lane1

Điều này KHÔNG nói bản thiết kế hiện tại sai. Nướng offset vào lệnh
tránh được một phép cộng địa chỉ mỗi lần truy cập, và theo CLAUDE.md
mục 6b thì tốc độ mô phỏng đứng trên số dòng phải sinh.

Điều nó nói là: chi phí BIÊN DỊCH và dung lượng I-cache tăng tuyến tính
theo số thực thể giống nhau, mà đó đúng là chế độ mà mũi nhọn sản phẩm
nhắm tới (N thực thể giống nhau về cấu trúc -- CLAUDE.md mục 5). Với
bốn lane thì 4x; với ba mươi hai lane thì 32x.

Câu hỏi còn bỏ ngỏ, CHƯA ĐO, đừng đọc thành kết luận: nếu offset trạng
thái được truyền qua thanh ghi nền thay vì nướng vào lệnh, một hàm biên
dịch một lần có phục vụ được cả N lane không, và đánh đổi giữa một phép
cộng địa chỉ mỗi truy cập với N lần ít biên dịch hơn nghiêng về bên
nào. Chưa ai đo, nên chưa ai biết. Liên quan tới nhóm bất biến song
song hoá BB-1..BB-6.


5. Giới hạn
------------

- Bộ mã này là của top gserdes_quad_tb. Bài nghiệm thu
  gserdes_quad_accept_tb là một top KHÁC, sinh bộ mã khác.
- Khoá băm của cache gồm featureList của CPU, LLVM_VERSION_STRING,
  kObjectCacheEdgeXVersion, kObjectCacheAbiTag, kObjectCacheOptTag,
  keySalt và chính IR. Đổi máy hay đổi phiên bản là đổi hết tên tệp.
  Cache KHÔNG ship theo sản phẩm.
- Thư mục jit-cache/ KHÔNG bị .gitignore bỏ qua. Đo bằng
  `git check-ignore -v Dev/demo/gSerDesQuad/jit-cache/`: không khớp
  mẫu nào, vì .gitignore chỉ có .edgex-cache/ và .edgex/. Nghĩa là
  nếu commit thư mục này thì 210 tệp .o vào theo. Nội dung là artefact
  sinh ra (CLAUDE.md mục 2 luật 5), nên muốn giữ hay loại đều phải
  quyết tường minh, không để mặc định quyết hộ.

- Cả thư mục nặng 33 MB, trong đó gserdes_quad.llvm.mlir chiếm 24,4 MB.
  Repo này từng chạm trần push 100 MB của GitHub (commit e59a47d).
  Nén gzip hai tệp MLIR còn 3,8 MB, tức giảm 7,5 lần mà không mất một
  byte nào.
