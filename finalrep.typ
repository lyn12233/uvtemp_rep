#import "typst_utils/utils.typ": *

#set text(..default_text_parm)
#set par(..default_par_parm)
#set table(stroke: none)
#set pagebreak(weak: true)

#set image(..default_image_parm)
#set grid(..default_grid_parm)
#show bibliography: set grid(..default_bib_grid_parm)

#show figure.where(kind: image): set figure(..default_FOI_parm)
#show figure.where(kind: table): set figure(..default_FOT_parm)
#show figure.caption: set text(size: font_size_zh.WuHao)
#show figure.where(kind: table): set figure.caption(position: top)

#show heading.where(level: 1): set heading(numbering: "1")
#show heading.where(level: 2): set heading(numbering: "1.1")

#show math.equation: set text(font: ("New Computer Modern Math", "SimSun"))

#set page(margin: (x: 3.18cm, y: 2.54cm))
#set text(top-edge: 1em, bottom-edge: "descender")
#set par(leading: 0.75em, spacing: 0.75em)

#Section("项目概述")

#FLI() SSH协议(Secure Shell Protocol)是一个旨在提供安全通信环境的加密网络协议; 本项目实现在嵌入式系统上搭建SSH服务器, 与SSH客户端建立远程连接, 提供SFTP服务, 最终实现基于SSH连接的文件上传, 下载等功能。在嵌入式系统上建立SSH服务器, 为嵌入式系统的远程交互提供了基础设施, 具有重要意义。

#SubSection("项目的选题意义")

#FLI() 许多嵌入式应用场景中存在与嵌入式系统远程交互的需求, 例如物联网设备更新、智能家居设备交互等。在这些场景中, 实现远程交互存在可靠性、易用性等问题。例如传统的串口通信距离受限, 通信协议没有同一标准, 迭代开发困难等。SSH协议长期应用于服务器远程管理、安全文件传输等方面, 已成为被广泛认可的安全通信协议, 在嵌入式领域中的应用有待探索。同时, 常见的SSH组件(如开源项目OpenSSH提供的ssh,sshd等)体积和内存占用大, 且高度依赖于套接字和进程管理等操作系统功能, 难以向嵌入式系统移植, 这限制了SSH在资源受限环境中的应用。本项目通过实现一个轻量级的嵌入式SSH服务器, 在保持协议安全性的前提下, 显著降低了资源占用, 使得在资源受限的MCU上运行SSH服务成为可能, 为嵌入式设备提供了一种标准、安全、便捷的远程交互解决方案。

#FLI() SFTP(Secure File Transport Protocol)是基于SSH连接的常用服务类型之一, 用于实现可靠的远程文件传输。搭建支持SFTP的SSH服务器可以展示嵌入式SSH服务器的应用价值, 同时作为简便的远程文件系统也具有很强的实用性

#SubSection("研究内容")

#FLI() 从硬件抽象程度来看, 本项目物理层面涉及MCU与外设的连接, 包括通过SDIO总线连接SD卡(作为存储器件), 通过USART(Universal Synchronous Asnychronous Receiver-Transmitter, 实际使用异步部分, 即UART)总线连接ESP8266-1S模块; 传输层面包括发送和解析ESP8266特定消息; 连接和会话层面包括SSH和SFTP协议的部分实现。

#SubSub("HAL库和SDIO/UART引脚功能")

// 大致解释hal_sdio接口, hal_uart中断传输方法

#SubSub("ESP8266功能和AT指令")

#FLI() ESP8266芯片支持WIFI连接和TCP传输, 最多可5个TCP连接; 本项目使用ESP8266-1S模块建立SSH通信所需的物理连接。ESP8266通过UART端口与MCU连接, 其发送和接收的指令格式称为AT指令。ESP接收的AT指令格式为 `AT.*\r\n`, 常见的指令有: `AT\r\n`, `ATE(0|1)\r\n`, `AT+UART_DEF=<baud>,<>\r\n`, `AT+CWMODE=(1|2|3)\r\n`, `AT+CWJAP=.*\r\n`, `AT+CIPMUX=(0|1)\r\n`(开启多链接模式), `AT+CIPSERVER=\d,\d+\r\n`(设置TCP状态和监听端口), `AT+CIPSEND=<id>,<len>\r\n`(发送数据到指定TCP连接)。ESP8266处理每一个指令后, 一定发送 `OK\r\n` 或 `ERROR\r\n` 消息来指示指令的执行是否成功。

#FLI() 本项目中, 与ESP8266通信要求严格的同步策略。第一, 实践得出ESP8266与MCU的通信是单工的, 同时收发数据会造成错误, 因此在MCU发出AT指令后必须等待ESP8266返回消息, 才能进行下一步处理。第二, ESP8266接收到客户端TCP消息包后会立即发送给MCU, 其格式为 `+IPD,<id>,<len>:<data>`, 对该消息的处理应与AT指令执行解耦。第三, MCU发送 `AT+CIPSEND=<id>,<len>\r\n` 需要等待ESP8266发送 `>` 后, 才能向其发送TCP数据, 并等待 `SEND OK\r\n` 或 `SEND FAILED\r\n` 消息。第四, TCP连接建立或断开, ESP8266会立即发送 `<id>,(CONNECT|CLOSED)` 消息。

#SubSub("SSH协议")

#FLI() SSH协议规定了一种加密的客户端-主机端通信框架, 有若干RFC(Request For Comments)标准组成。

#FLI() RFC4251标准定义了SSH协议使用的基本数据类型: `byte, boolean, uint32, uint64, mpint, string, name-list`, 其中前4项是如字面意义所示的定长数据, `byte, boolean` 是单字节, `uint32, uint64` 采用大端的字节顺序; `mpint, string, name-list` 是变长数据, 将前4字节解释为 `uint32`, 表示后续字节数; `mpint` 编码大端不定长整数值, 整数部分的最高字节是否为零表示整数的正负。

#FLI() RFC4253标准定义了SSH数据包格式, 连接建立流程和密钥交换流程。SSH数据包格式 `{uint32 packet_length; byte padding_length; byte payload[]; byte padding[]; byte mac[]}`, 其中 `packet_length` 表示后续数据长度, `padding_length` 表示随机填充长度, `payload` 为实际数据, `padding` 是随机填充部分, `mac` 是消息认证代码(message authentication code, mac), 用于验证数据的真实性; 当底层连接建立后, SSH双方立即发送以 `\r\n` 结束的版本信息; 交换版本信息后立即发送SSH_MSG_KEXINIT消息开始协商加密算法, 协商应当得出密钥交换(key exchange, kex)算法, 主机签名算法(host key algorithm), 加密(encryption, cipher)算法和消息认证算法(mac algorithm), 其中密钥交换算法用于共享密钥的计算, 主机签名算法用于客户端认证主机身份, 加密算法用于加密SSH数据包, 消息认证算法用于生成mac, 验证数据的真实性。基于协商结果进行密钥交换后, 双方发送SSH_MSG_NEWKEYS消息并开始加密传输。双方维护双向的序列号(sequence number, 即数据包发送到个数)保证数据传输的可靠性。

#FLI() RFC4252标准定义了SSH用户面向主机的认证方法。在交换SSH_MSG_NEWKEYS后, 客户端发送SSH_MSG_USERAUTH_REQUEST消息, 在 `mathod_name` 位指定认证方法, 包括公钥认证(), 密码认证()和无认证方法等。主机端发送SSH_MSG_USERAUTH_SUCCESS表示认证成功或发送SSH_MSG_USERAUTH_FAILURE提示进一步认证。

#FLI() RFC4254标准定义连接层协议, 规定客户端发送SSH_MSG_CHANNEL_OPEN打开逻辑信道(channel), 主机回应SSH_MSG_CHANNEL_OPEN_CONFIRMATION得到信道收发端的标识; 在逻辑信道上, 双方收发SSH_MSG_CHANNEL_DATA消息进行数据传输; 客户端发送SSH_MSG_CHANNEL_REQUEST请求具体服务, 包括打开命令行(shell), 执行命令(exec)和打开预定义子系统(subsystem)等。

#SubSection("技术指标与功能")
#FLI() 本项目将在嵌入式系统上实现建立SSH连接的功能, 提供SFTP服务, 实现SD卡读写, 最终实现在上位机上传和下载开发板+SD卡中的文件。具体指标如下。

#[
  #set align(center)
  #figure(
    table(
      table.hline(y: 0, stroke: 1pt),
      table.hline(y: 1, stroke: 0.5pt),
      table.hline(y: 9, stroke: 1pt),
      columns: 2,
      [指标], [值],
      [烧录文件大小], [\<170KB 或 \<50KB#super("*1")],
      [RAM占用], [\<50KB],
      [SSH连接数], [1],
      [SSH连接建立时间], [10\~20s 或 1\~2min#super("*1")],
      [传输文件大小], [无限制#super("*2")],
      [密钥交换算法], [curve25519-sha256],
      [主机签名算法], [ssh-ed25519],
      [加密算法], [chacha20-poly1305\@openssh.com],
    ),
    caption: "本项目技术指标",
  )
  #set text(size: font_size_zh.WuHao)
  \*注: 1. 使用本项目实现的椭圆曲线标量乘法, 进行直接计算而非查表, 从而牺牲时间取得了更好的体积。 2. 由于采用了分段处理的方法, 理论上不会出现堆溢出的情况, 文件大小还受实际存储能力限制。
]

#Section("方案设计")

#SubSection("总体方案")

#FLI() 本项目包含文件业务, 通信业务, SSH解析和会话, SFTP解析和会话等4大业务模块, 主要聚焦于网络通信和会话部分。项目总体实现为 "发送-接收" 网络通信模型, 对不同层次的通信业务进行解耦, 如@network 所示。

#[
  #figure(image("data/3.svg", width: 8cm, height: 6cm), caption: "本项目实现的网络通信模型")<network>
]

#FLI() 总体构建方案如下:

(1) 引入HAL库, FatFS库和FreeRTOS库, 实现必需的接口函数, 搭建基本的开发环境。

(2) 实现时钟, 引脚和SD卡外设的初始化, 并测试FreeRTOS进程和FatFS文件读写等功能。

(3) 实现变长数据和可变类型的构造, 析构, 追加等相关功能。

(4) 在此基础上, 以套接字(scoket)接口作为分界并行开发:

#[
  #set par(first-line-indent: 1em, hanging-indent: 1em)

  \u{2460} 开发ESP8266消息解析和指令执行, 提供socket接口。
  #[
    #set par(first-line-indent: 2em, hanging-indent: 3em)
    · 基于FreeRTOS管道和HAL_UART中断传输实现...

    · 解析AT消息并输出调试信息, 并实现AT指令执行。

    · 实现AT指令执行和消息解析的同步策略, 实现TCP回声测试。

    · 实现socket接口, 实现基于FreeRTOS进程和socket接口的TCP回声测试。
  ]
  \u{2461} 实现基于socket的SSH连接

  #[
    #set par(first-line-indent: 2em, hanging-indent: 3em)
    · 参考OpenSSH源代码, 在上位机构建基于win32api的SSH服务器。

    · 在OpenSSH源代码中插入调试信息, 在上位机编译得到用于调试的SSH客户端。

    · 在上位机调试SSH会话逻辑, 修复逻辑漏洞。

    · 尝试实现更为简洁的椭圆曲线标量乘法。

    · 将SSH服务器移植到嵌入式系统。
  ]
]

(5) 在嵌入式系统上, 基于SSH连接接受SFTP服务并解析符合SFTP协议的数据, 通过FatFS处理SFTP请求, 实现文件传输。

#SubSection("源代码组织结构, 功能和调用关系")

#FLI() 本项目代码构成一个uvprojx项目, 代码的基本结构为(只展示文件夹和本项目修改或创建的文件):

(1) `Core/`: 入口点, C函数入口, 中断向量表和核心回调函数定义。

#[
  #set par(first-line-indent: 1em, hanging-indent: 1em)

  \u{2460} `Src/freertos_hooks.c`: 为FreeRTOS提供的回调函数以及系统时钟回调。

  \u{2461} `Src/main.c`: C函数入口。
]

(2) `Drivers/`: HAL库和CMSIS库。

(3) `FatFS/`: FatfS库。

(4) `FreeRTOS/`: FreeRTOS库。

#[
  #set par(first-line-indent: 1em, hanging-indent: 1em)
  \u{2460} `port/FreeRTOSConfig.h`: FreeRTOS配置。
]

(5) `IOLibrary/`: 未使用。

(6) `StdPort/`: 提供自定义类标准的文件头。

#[ #set par(first-line-indent: 1em, hanging-indent: 1em)

  \u{2460} `allocator.h`: 使用 `portMalloc, portFree` 覆盖 `malloc, free`。

  \u{2461} `log.c(.h)`: 自定义 `printf, puts`。

  \u{2462} `port_errno.h, port_socket.h, port_unistd.h`: 提供错误代码和大小端转换。
]

(7) `Task/`: FreeRTOS进程。

#[ #set par(first-line-indent: 1em, hanging-indent: 1em)

  \u{2460} `blink_task.c(.h)`: 用于调试, 闪烁LED指示FreeRTOS调度正常。

  \u{2461} `tcp_echo_task.c(.h)`: 用于回声测试, 未使用。

  \u{2462} `tcp_sshd_task.c(.h)`: SSH服务单例, 调用SSH会话各部分逻辑。
]

(8) `User/`: 主要项目代码。

#[ #set par(first-line-indent: 1em, hanging-indent: 1em)
  \u{2460} `crypto/`: 加密算法实现。

  #[ #set par(first-line-indent: 1em, hanging-indent: 1em)

    · `crypto_api.h`: 所有算法的头文件, 来自OpenSSH, 稍有修改。

    · `ed25519-2.c`: ed25519签名算法, 来自OpenSSH, 稍有修改。

    · `ed25519-4.c, ed25519-4bignum.c`: ed25519签名算法, 修改了椭圆曲线域标量乘法以实现更小的体积。

    · `random.c`: 伪随机数生成。
  ]
  \u{2461} `esp/`: 基于ESP8266的通信模块。

  #[ #set par(first-line-indent: 2em, hanging-indent: 3em)

    · `esp_sock.c(.h)`: 基于ESP8266的socket接口。

    · `exec.c(.h)`: AT指令执行逻辑和相关数据初始化。

    · `parser.c(.h)`: AT消息解析逻辑和相关数据初始化。
  ]

  \u{2462} `ssh/`: SSH和SFTP会话逻辑。

  #[ #set par(first-line-indent: 2em, hanging-indent: 3em)

    · `acpt_loop.c(.h)`: SFTP接收循环。

    · `packet_def.c(.h)`: SSH特定数据包结构定义, 数据包列表初始化功能。

    · `pakcet.c(.h)`: SSH数据包处理, 发送和接收, 加密发送和接收。

    · `s1_kexinit.c(.h)`: SSH版本交换和SSH_MSG_KEXINIT消息交换

    · `s2_ecdh_init.c(.h)`: 接收SSH_MSG_ECDH_INIT, 计算密钥, 签名, 发送SSH_MSG_ECDH_REPLY。

    · `s3_userauth.c(.h)`: SSH用户认证。

    · `s4_openchnl.c(.h)`: 打开SSH信道(channel)并响应SFTP服务。

    · `sftp_parse.c(.h)`: SFTP数据包解析和业务实现。

    · `sftp_task.c(.h)`: 未使用。

    · `ssh_context.c(.h)`: SSH上下文定义和初始化。

  ]

  \u{2463} `types/`: 可变长数据类型和变体(variant)类型实现。
  #[ #set par(first-line-indent: 2em, hanging-indent: 3em)

    · `vo.c(.h)`: 定义 `vstr_t, vlist_t, vo_type_t, vo_t` 类型和相关处理函数; 其中 `vstr_t` 为可变长缓冲, `vlist_t` 为变长列表; `vo_t` 为variant类型, 可用类型由 `vo_type_t` 定义。
  ]

  \u{2464} `user_init/`: 引脚, 外设和AT指令执行和解析进程初始化。

  \u{2464} `user_main.c`: 项目入口点。
]

#FLI() 软件各部分调用关系较为明显: `Driver/` 提供基本硬件管理, `FreeRTOS/` 基于 `Driver/` 实现简化的操作系统功能, `FatFS/` 依赖 `Driver/` 实现SD卡读写; `User/types/vo.c` 依赖 `FreeRTOS/` RAM动态分配; `User/esp/` 部分功能作为FreeRTOS进程存在; `User/ssh/` 调用 `User/esp/` 所提供的socket接口; 所有用户实现部分高度依赖 `FreeRTOS/` 和 `User/types/vo.c` 提供的基础功能。

#Section("硬件设计")

#FLI() 使用"普中-玄武"开发板, MCU为stm32f103ze。SD卡通过SDIO连接; ESP8266-1S模块通过USART3连接。依据开发板原理图, SDIO使用MCU引脚PC8\~PC11作为数据传输线SDIO_D0\~SDIO_D3, PD2作为同步信号SDIO_SCK; 调试使用USART1, 引脚PA9, PA10对应USART1_TX, USART_1_RX; 与ESP8266通信使用USART3, PB10, PB11对应USART3_TX, USART3_RX。处于调试的目的, 同时使用了PB5控制开发板上的红色LED来提示运行状态。

// 仿照PPT截取/data/schemantic.pdf, 直接用画图工具绘制成jpg, x3

// im1 im2 im3

#Section("软件设计")

// 功能模块, 状态机, 流程, 代码,

#SubSection("主要功能设计")

#FLI() 通信业务部分设计如@im4 所示。其中AT消息解析部分按字节立即读取输入, 识别到完整消息则进行分发, 将TCP连接建立和关闭消息存入和 `conn_state` 状态表, 连接建立的消息同时存入 `preaccept` 管道; 对执行结果消息存入 `atc_sendres` 管道, 将接收到的数据按 `vstr_t` 形式存入 `conn_recv` 管道, 同时推导ESP8266状态 `atc_peri_state`; AT执行部分传入 `atc_cmd_t` 形式的参数, 通过等待 `atc_peri_state, atc_sendres, atc_senddone` 状态进行同步; socket接口基于上述组件建立, 在程序中主要使用 `sock_send, sock_recv` 进行通信, 其中 `sock_recv` 读取 `conn_recv` 和 `esk_recv_buff` 中预存的信息, 根据要求读取的长度对接收到的 `vstr_t` 格式数据进行拼接, 剩余部分存储于 `esk_recv_buff`。通过 `atc_per_state` 体现的状态模型以及AT消息按字节解析的状态模型如@im5 所示。

// im4 im5 --im6--

#[
  #set align(center)

  #figure(image("data/test1.svg", width: 8cm, height: auto, fit: "contain"), caption: "ESP8266解析执行功能")<im4>

  #figure(image("data/2.svg", width: 8cm, height: auto, fit: "contain"), caption: "ESP8266状态模型")<im5>


]

#FLI() SSH连接建立, 认证和交互的具体流程和计算步骤如@im6, @im7 所示, 这一过程线性进行, 没有复杂的状态逻辑。

//im6 im7
#[
  #set align(center)
  #grid(
    columns: (1fr, 1fr),
    align: bottom,
    [
      #figure(image("data/sshsetup.svg", height: auto, width: auto), caption: "SSH连接建立流程")<im6>
    ],
    [
      #figure(image("data/sshsvc.svg", height: auto, width: auto), caption: "SSH认证和交互(以SFTP子系统为例)")<im7>
    ],
  )
]


#SubSection("关键代码解释")


#SubSub("可变长数据和可变类型实现")

#FLI() 在 `User/types/vo.c` 中, `vstr_t` 用于存储以字节为单位的变长数据, `vo_t` 用于存储variant可变类型数据, `vlist_t` 用于存储以 `vo_t` 为条目的列表; 其数据格式为如下。

//c1
#[
  #let c1 = read("data/c1.txt")
  #set par(spacing: 0em, leading: 0em)
  #grid(
    inset: 3pt,
    stroke: 1pt,
    columns: 1fr,
    align: left,
    [
      #raw(c1, lang: "c")
    ],
  )
]

#FLI() 可变长数据的存储是基于FreeRTOS动态分配的, 在进行 `vbuff_iadd, vbuff_iaddc, vbuff_iaddu32` 等操作时,数据长度可以动态增长; `vstr_reserve` 用于确保足够数据空间, 当空间不足时以1.5倍的大小重新分配; 其实现如下。

//c2
#[
  #let c2 = read("data/c2.txt")
  #set par(spacing: 0em, leading: 0em)
  #grid(
    inset: 3pt,
    stroke: 1pt,
    columns: 1fr,
    align: left,
    [
      #raw(c2, lang: "c")
    ],
  )
]

同时 `vo_t` 支持通过初始化表生成, 用于快速建立SSH数据包, 实现如下。

//c3
#[
  #let c2 = read("data/c3.txt")
  #set par(spacing: 0em, leading: 0em)
  #grid(
    inset: 3pt,
    stroke: 1pt,
    columns: 1fr,
    align: left,
    [
      #raw(c2, lang: "c")
    ],
  )
]

#SubSub("通信业务实现")

#FLI() 在 `User/esp/parser.c` 中, AT消息解析流程如下。这一解析流程可以保证出现错误时总能回到 `` 状态, 具有良好健壮性。

//c4
#[
  #let c2 = read("data/c4.txt")
  #set par(spacing: 0em, leading: 0em)
  #grid(
    inset: 3pt,
    stroke: 1pt,
    columns: 1fr,
    align: left,
    [
      #raw(c2, lang: "c")
    ],
  )
]

#FLI() 在 `User/esp/exec.c` 中, AT指令执行部分如下。其关键在于 `AT+CIPSEND` 中的同步处理和错误消息汇报。

//c5
#[
  #let c2 = read("data/c5.txt")
  #set par(spacing: 0em, leading: 0em)
  #grid(
    inset: 3pt,
    stroke: 1pt,
    columns: 1fr,
    align: left,
    [
      #raw(c2, lang: "c")
    ],
  )
]

#FLI() 在 `User/esp/esp_sock.c` 中, `sock_recv` 处理预存数据的实现如下。

//c6
#[
  #let c2 = read("data/c6.txt")
  #set par(spacing: 0em, leading: 0em)
  #grid(
    inset: 3pt,
    stroke: 1pt,
    columns: 1fr,
    align: left,
    [
      #raw(c2, lang: "c")
    ],
  )
]

#SubSub("SSH相关组件实现")

#FLI() 在 `User/ssh/ssh_context.c` 中, SSH上下文信息定义如下。

//c7
#[
  #let c2 = read("data/c7.txt")
  #set par(spacing: 0em, leading: 0em)
  #grid(
    inset: 3pt,
    stroke: 1pt,
    columns: 1fr,
    align: left,
    [
      #raw(c2, lang: "c")
    ],
  )
]

#FLI() 在 `User/ssh/packet.c` 中, SSH数据包接收, 加密接收和发送的代码如下。

//c8
#[
  #let c2 = read("data/c8.txt")
  #set par(spacing: 0em, leading: 0em)
  #grid(
    inset: 3pt,
    stroke: 1pt,
    columns: 1fr,
    align: left,
    [
      #raw(c2, lang: "c")
    ],
  )
]


#FLI() `packet.c` 同样实现了从 `vo_t` 构建数据包, 代码较为冗长, 不在此展示。

#FLI() 在 `User/ssh/acpt_loop.c, User/ssh/s*_***.c` 中, SSH连接建立部分严格按照SSH标准实现, 较为冗长, 不在此展示, 只展示主干部分。

//c9
#[
  #let c2 = read("data/c9.txt")
  #set par(spacing: 0em, leading: 0em)
  #grid(
    inset: 3pt,
    stroke: 1pt,
    columns: 1fr,
    align: left,
    [
      #raw(c2, lang: "c")
    ],
  )
]

#FLI() 在 `User/ssh/sftp_parse.c` 中, SFTP消息解析和响应逻辑主要为 `sftp_parse, sftp_dispatch, sftp_dispatch_spkt, continue_write`; 实现如下。

//c10
#[
  #let c2 = read("data/c10.txt")
  #set par(spacing: 0em, leading: 0em)
  #grid(
    inset: 3pt,
    stroke: 1pt,
    columns: 1fr,
    align: left,
    [
      #raw(c2, lang: "c")
    ],
  )
]

#Section("结果")

#FLI() 建立演示环境时, 首先通过上位机向ESP8266写入WIFI配置, 将SD卡和ESP8266-1S模块插入开发板指定位置, 完成烧录并运行; 确保上位机与开发板处于同一子网中或可以互相通信(本项目中连接至移动热点以方便调试)。

#FLI() 在上位机确保安装OpenSSH相关组件, 运行 `sftp -v -P <port> <ip>`, 其中 `-v` 表示输出详细信息, `-P <port>` 表示ESP8266监听端口, 在本项目中设置为8080 , `<ip>`是开发板ipv4地址。命令行出现 `sftp>` 表示SFTP交互服务成功建立。由于ESP8266自身缺陷可能存在丢包的情况, 或者FatFS无法初始化, 这时对开发板断电重启可以解决问题。

#FLI() 在SFTP交互服务中, 默认挂载目录为 `/`; 可以运行 `ls` 查看开发板SD卡中的文件, `ls -l` 可以查看文件具体属性, `pwd` 可以查看当前目录(始终为 `/`), `lls` 可以查看本地文件, `lpwd` 查看本地目录; 使用 `put <filename>` 上传文件, `get <filename>` 下载文件, `rm <filename>` 删除文件, `exit` 关闭连接; 部分功能(如`rename, readlink`等)没有实现, 会提示错误。

#FLI() 一个展示示例如下。以下图像左侧窗口为执行sftp的命令行; 右侧窗口为串口输出, 此时电脑作为上位机, 与开发板通过USB连接, 输出开发板调试信息。

#[
  #set align(center)
  #set image(width: auto, height: auto)
  #set par(spacing: 1em, leading: 0em)

  #figure(image("data/demo/img1.png"), caption: "上位机执行sftp指令, SSH双方交换版本信息和KEXINIT消息")
  #figure(
    image("data/demo/img2.png"),
    caption: "SSH客户端根据KEXINIT消息选择算法, 发送KEX_ECDH_INIT, 服务端(开发板)开始计算共享密钥K和签名s",
  )
  #figure(image("data/demo/img3.png"), caption: "服务端计算得到K和s, 发送KEX_ECDH_REPLY")
  #figure(
    image("data/demo/img4.png"),
    caption: "客户端接收KEX_ECDH_REPLY, 完成用户验证, 打开session信道, 发出sftp子系统信道请求",
  )
  #figure(image("data/demo/img5.png"), caption: "sftp双方交换版本信息, sftp客户端确定服务端当前路径")
  #figure(
    image("data/demo/img6.png"),
    caption: "客户端执行'ls -l'展示服务端文件, 服务端解析FXP_READDIR等命令; 客户端执行'lls -l'展示本地文件",
  )
  #figure(image("data/demo/img7.png"), caption: "客户端下载文件, 服务端分步读取文件以避免堆溢出")
  #figure(image("data/demo/img8.png"), caption: "文件下载完成")
  #figure(image("data/demo/img9.png"), caption: "客户端路径下出现了被下载的文件, 大小与原文件一致")
  #figure(image("data/demo/img_10.png"), caption: "客户端上传文件, 服务端分步读取网络数据以避免堆溢出")
  #figure(image("data/demo/img_11.png"), caption: "文件上传完成")
  #figure(image("data/demo/img_12.png"), caption: "服务端出现了上传的文件, 大小与原文件一致")
  #figure(image("data/demo/img_13.png"), caption: "客户端关闭, 服务端相应的结束TCP连接")
  #figure(image("data/demo/img_14.png"), caption: "交互结束后, 上位机本地内容(client_data.txt)")
  #figure(image("data/demo/img_15.png"), caption: "交互结束后, 上位机本地内容(server_dat.txt)")
  #figure(image("data/demo/img_16.png"), caption: "交互结束后, 开发板SD卡中的内容(client_dat.txt)")
  #figure(image("data/demo/img_17.png"), caption: "交互结束后, 开发板SD卡中的内容(server_dat.txt)")

]

//im8 cmd

//im9 kexinit

//im10 calc K(x)

//im11 signing

//im12 userauth

//im13 ls 1

//im 14 lls 1

// im15 put

//im 16 get

//im18 ls 2

//im 19 20 exit

//imt21 cat

//im 22 23 sd
