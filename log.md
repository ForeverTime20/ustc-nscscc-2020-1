[toc]

## 7.26

1.添加硬件中断的支持。

2.取指令的时候地址前三位也要清零，不然没法读外设。

3.系统测试里要用 LB 才能读串口寄存器在内存地址的映射，用 LW 只能读内存，故修改 MEM 段。

4.ERET 清空 status.EXL 使用减法，如果 status.EXL 不是零会有问题，改为用 isERET 判断。（?）

5.增加 mul (取低位无符号乘法) 指令。

6.中断不需要写 status.IM 和 status.IE 。

## 7.9

**发现的问题：**

1.CPU不支持软件中断

2.软件中断写EPC时PC数据无效

3.软件中断例外编码错误

4.软件中断后CP0的Status和Cause寄存器与参考值校验失败

5.软件中断屏蔽不完善导致写CP0出现问题

6.未对发生例外的指令判断是否在延迟槽中

7.未在cause寄存器中描述发生例外的指令是否在延迟槽中

8.J、JAL、JR、JALR指令执行时isBranch信号为0

9.SRL指令写入错误

**解决方案：**

1.在例外处理模块添加了对软件中断的处理，顶层模块改写了软件中断的输入信号

2.增加寄存器pc_old来记录上个周期PC

3.修复了顶层模块Exception.Status_IM赋值错误，修改了例外处理模块Cause_IP的信号

4.修改了例外处理模块写cause和status的部分

5.在we[12-14]前增加了!Status.EXL条件

6.从ID段随流水线传一信号is_ds到例外处理模块标识是否为延迟槽指令

7.修复了顶层文件中ID段延迟槽信号没有传递的问题

8.相应的在控制单元中添加了J类指令

9.发现是冒险检测单元把RegWritew信号名字打错了，已改正（之前居然一直没报错）

**结果：**

1.通过原出错地址，仍未通过77号测试点

2.通过原出错地址，仍未通过77号测试点

3.通过原出错地址，仍未通过77号测试点

4.通过原出错地址，仍未通过77号测试点；例外处理模块经过这么多次修改非常不适合阅读，建议之后整理例外处理模块的信号和对应的取值表。

5.通过77号测试点，未通过78号

6.通过原出错地址，仍未通过78号

7.通过85号测试点，未通过86号测试点

8.通过89个测试点，但通过后仍提示有错

9.过了

## 7.8

**发现的问题：**

1.ERET写PC时EPC未正确传递，未修改CP0.Status.EXL位，未flush流水线

2.CPU未响应第二个syscall，ERET指令置Status.EXL位失败

3.break指令没有写入EPC

4.*branch 等指令被等效成 ADD ，导致了不该有的溢出

*有异常写回段仍写回了错误结果

5.*判断是 load 还是 store 地址错的条件错

*地址错异常不能存数据

6.没有设置 BadVAddr 寄存器

7.没有处理取指 PC 不对齐于字边界产生的异常

8.没考虑 EPC 也有可能没对齐

9.ERET 导致的地址错例外，新的 EPC 是原来的 EPC 而不是 ERET 的 PC

10.没处理保留指令异常

**解决方案：**

1.ERET等效为 ADDIU	CP0.Status	​CP0.Status	-2 ，通过ID段的译码模块实现

2.改变了读Status的端口

3.Exception_deal_module中增加了对_break信号的判断

4.*改成 ADDU

*添加 RegWrite 的判断条件

5.*应为 MemWrite

*修改 calWE

6.从 WB 段把 aluout 连到 Exception 单元，同时连接 ID 段与 CP0 的 BadVAddr

7.考虑到优先级问题，添加 PCError 异常

8.*修改 ID 段译码器，增加 ALU_ERET  ERET_EXP ，使 WB 段和 Exception 单元能够知道当前的指令是 ERET 

*将 ID 段的 EPC 接到 Exception 单元，用于判断是否对齐

9.增加 EPC 的判断条件

10.增加保留异常：在 ID 段判断，传到 EX 段，exception 不够用了，扩成4位宽

**结果：**

1.ERET指令通过，仍未通过65号测试点

2.通过65号测试点，未通过66号

3.通过66号测试点，未通过67号

4.通过67号测试点，未通过70号

5.通过之前的出错地址，仍未通过70号

6.通过70号测试点，未通过75号

7.通过之前的出错地址，仍未通过75号

8.通过之前的出错地址，仍未通过75号

9.通过75号测试点，未通过76号

10.通过76号测试点，未通过77号（软件中断，在一个 branch 处反复横跳）

## 7.7

**发现的问题：**

1.分支判断数值不是有符号的

2.分支需要写寄存器时写入的数据错误

3.分支写入的imm_sel寄存器无需分支发生branch_taken

4.JALR指令写入寄存器号错误

5.div指令在ALU发出stall请求时Harzard Unit没有stall

6.FlushE时ID/EX的EPC_sel被清为0，导致PC地址被非预期地址修改，以及div计算出的HILO结果无法被旁路

7.div_control.sv中的div_count在除法执行完后会继续递减，导致后续的除法指令出错

8.load 和 store 的大小尾端反了。

9.SB 和 SH 要求把 Rt 寄存器的低位存到内存地址处，现在是对应位存到该处。

**解决方案：**

1.在ID模块的branch_judge中加上signed声明

2.*修改了instruction.vh中的\`FUNC_BGEZAL和\`FUNC_BLTZAL声明错误

​	*修改了ID段Control Unit中控制ALUSrcA和B的信号，详见控制信号表格

​	*修改了branch_judge中的RegWriteBD信号，在BLTZAL和BGEZAL这两个指令分支不发生时也有效

3.修改了ID段传给EX的Imm_sel_and_branch_taken为Imm_sel

4.修改了控制单元中JALR指令的RegDst信号为1（即选择Rd写入），更新了控制信号表格

5.修改了Harzard Unit的状态机使得其支持div的stall

6.*修改IF.v使EPC_sel为0时候不选EPC；修改Hazard Unit 的状态机使其在div或mul指令后stall IF、ID两周期。

​	*修改了alu.sv中div时hilo的输出，高位32为余数，低32位为商。

7.在div_control.sv中div_count复位处增加判断条件!div_done

8.WB 段选择取数据结果改为后面是 0 ，前面是 3，MEM 段 calWE 做同上修改。

9.MEM 段设置 TrueRamData。

**结果：**

1.通过36号测试点，在41号测试点发生错误

2.通过先前发生错误的地址，在新的地址发生错误，仍未通过41号测试点

3.通过41号测试点，未通过42号测试点

4.通过42号测试点，未通过44号测试点

5.stall成功，但在写入时出错，仍未通过原出错地址

6.通过原出错地址，仍未通过44号测试点

7.爽了，过了58个测试点，第59个没过（LB部分）

8.通过58号测试点，未通过63号测试点

8.通过63号测试点，未通过65号测试点

## 7.6

### jbz

发现的问题：

1.当EX段需要WB段旁路过来的数据，并且EX和MEM段将被stall，WB段继续执行时，下个周期旁路的数据会丢失，使得EX段的数据不是最新的。

2.IF,ID同时被stall时，从指令ram中取出的指令会被后一条覆盖。

解决方法：

1.在harzard unit的ForwardAD和ForwardBD判断逻辑上删除了isaBranchInstruction，使非分支指令能在ID段获得来自MEM段旁路的信号。

2.在IF模块中增加输出is_newPC，该信号表示当前的PC的值与上一个PC是否相同，不相同为1。IF/ID段间寄存器的Flush使能由Hazard.FlushD | ID.CLR_EN改为Hazard.FlushD | ID.CLR_EN | IF.is_newPC，使段间寄存器在PC为刚改变的值时不接收instr RAM的数据。PC的stall使能信号改为IF.StallF | (IF.is_newPC && ID.EPC_sel && !ID.Jump && !ID.BranchD)，即当ID段不需要跳转且PC为刚刚改变的值时stall，使PC的值维持一个周期不变。

### wyt

延迟槽内的指令需要执行，但是由于取指改成两个周期了，跳转地址写回 PC 的时候恰好是上一条指令应该被取出来的那个周期，这样会导致时序混乱，过不了 trace 。

解决方案：把 ID 段分支的结果空传到 EX 段。

合并了目前的代码。

现在任意两条指令之间都含有一个 nop ，所以 Hazard 单元中只需考虑 branch 指令在 ID 段，lw 指令在 MEM 段的 stall 一个周期。