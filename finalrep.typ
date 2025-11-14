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

#FLI() 许多嵌入式应用场景中存在与嵌入式系统远程交互的需求, 例如...等。在这些场景中, 实现远程交互存在可靠性, 易用性等问题。例如...。SSH协议长期应用与..等方面, 已成为被广泛认可的安全的通信协议, 在嵌入式领域中的应用有待探索。同时, 由于协议的复杂性, 常见的SSH组件(如开源项目OpenSSH提供的ssh,sshd等)体积和内存占用大, 且高度依赖于套接字和进程管理等操作系统功能, 难以向嵌入式系统移植, 这...

#FLI() 一些研究...

#FLI() SFTP(Secure File Transport Protocol)是基于SSH连接的常用服务类型之一, 用于实现可靠的远程文件传输。搭建支持SFTP的SSH服务器可以展示嵌入式SSH服务器的应用价值, 同时作为简便的远程文件系统也具有很强的实用性。

#SubSection("研究内容")

#SubSub("HAL库和SDIO/UART引脚功能")

#SubSub("ESP8266功能和AT指令")

#FLI() ESP8266芯片支持WIFI连接TCP传输; 本项目使用ESP8266-1S模块建立SSH通信所需的物理连接。ESP8266通过UART端口与MCU连接, 其发送和接收的指令格式称为AT指令。ESP接收的AT指令格式为 `AT.*\r\n`, 常见的指令有: `AT\r\n`, `ATE(0|1)\r\n`, `AT+UART_DEF=<baud>,<>\r\n`, `AT+CWMODE=(1|2|3)\r\n`, `AT+CWJAP=.*\r\n`, `AT+CIPMUX=(0|1)\r\n`(开启多链接模式), `AT+CIPSERVER=\d,\d+\r\n`(设置TCP状态和监听端口), `AT+CIPSEND=<id>,<len>\r\n`(发送数据到指定TCP连接)。ESP8266处理每一个指令后, 一定发送 `OK\r\n` 或 `ERROR\r\n` 消息来指示指令的执行是否成功。

#FLI() 本项目中, 与ESP8266通信要求严格的同步策略。第一, 实践得出ESP8266与MCU的通信是单工的, 同时收发数据会造成错误, 因此在MCU发出AT指令后必须等待ESP8266返回消息, 才能进行下一步处理。第二, ESP8266接收到客户端TCP消息包后会立即发送给MCU, 其格式为 `+IPD,<id>,<len>:<data>`, 对该消息的处理应与AT指令执行解耦。第三, MCU发送 `AT+CIPSEND=<id>,<len>\r\n` 需要等待ESP8266发送 `>` 后, 才能向其发送TCP数据, 并等待 `SEND OK\r\n` 或 `SEND FAILED\r\n` 消息。第四, TCP连接建立或断开, ESP8266会立即发送 `<id>,(CONNECT|CLOSED)` 消息。

#SubSub("SSH协议")

#SubSub("SFTP协议")

#SubSection("技术指标与功能")
#FLI() 本项目将在嵌入式系统上实现建立SSH连接的功能, 提供SFTP服务, 实现SD卡读写, 最终实现在上位机上传和下载开发板+SD卡中的文件。具体指标如下。

#[
  #set align(center)
  #grid(
    [指标],
    [值],
    [烧录文件大小],
    [\<170KB],
    [RAM占用],
    [\<50KB],
    [SSH连接数],
    [1],
    [],
    [],
    [],
    [],
    [],
    [],
  )
]

#Section("方案设计")

#SubSection("总体方案")

#FLI() 本项目包含文件业务, 通信业务, SSH解析和会话, SFTP解析和会话等4大业务模块。总体构建方案如下:

(1) 引入HAL库, FatFS库和FreeRTOS库, 实现必需的接口函数, 搭建基本的开发环境。

(2) 实现时钟, 引脚和SD卡外设的初始化, 并测试FreeRTOS进程和FatFS文件读写等功能。

(3) 在此基础上, 以套接字(scoket)接口作为分界并行开发:

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

(4) 在嵌入式系统上, 基于SSH连接接受SFTP服务并解析符合SFTP协议的数据, 通过FatFS处理SFTP请求, 实现文件传输。

#SubSection("源代码组织结构和对应功能")

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

#Section("硬件设计")

#FLI() 使用"普中-玄武"开发板, MCU为stm32f103ze。SD卡通过SDIO连接; ESP8266-1S模块通过USART3连接。

// 仿照PPT截取/data/schemantic.pdf, 直接用画图工具绘制成jpg

#Section("软件设计")

// 功能模块, 状态机, 流程, 代码,

#Section("结果")
