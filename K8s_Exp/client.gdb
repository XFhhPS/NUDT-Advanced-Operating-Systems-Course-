############################################
# 记录与基础设置
############################################
target remote localhost:1234
set pagination off
set logging file client_debug1.log
set logging overwrite on
set logging on
display $lx_current().pid
display $lx_current().comm

############################################
# 小工具：打印指针
############################################
define pptr
    # $arg0 = 指针/整数
    printf "0x%08x", (unsigned int)$arg0
end

############################################
# 断点区
############################################
define setup_breaks
    # ────────── 系统调用层 ──────────
    break sock_sendmsg
    commands
        printf "[SOCK] sock_sendmsg sock="
        pptr sock
        printf "\n"
        p sock->sk_state
        p sock->sk_portpair      
    end

    # ────────── 协议栈层 ──────────
    break inet_sendmsg
    commands
        printf "[INET] inet_sendmsg entered\n"
    end

    # ────────── 传输层 ──────────
    break tcp_sendmsg
    commands
        printf "[TCP ] tcp_sendmsg sk="
        pptr sk
        printf "\n"
        p sk->sk_state
        p/x sk->__sk_common.skc_daddr
        p/x sk->__sk_common.skc_rcv_saddr
    end

    break tcp_transmit_skb
    commands
        printf "[TCP ] tcp_transmit_skb skb="
        pptr skb
        printf "\n"
        p skb->len
        x/32bx skb->data
    end

    # ────────── 网络层 ──────────
    break ip_queue_xmit
    commands
        set $_skb = skb
        printf "[IP  ] ip_queue_xmit skb="
        pptr $_skb
        printf "\n"
        p $_skb->len
        p $_skb->protocol
        x/32bx $_skb->data
    end

    break ip_output
    commands
        printf "[IP  ] ip_output skb="
        pptr skb
        printf "\n"
        p skb->len
    end

    # ────────── 链路层 ──────────
    break dst_neigh_output
    commands
        printf "[DST ] dst_neigh_output skb="
        pptr skb
        printf "\n"
        p skb->len
    end

    break neigh_hh_output
    commands
        printf "[DST ] neigh_hh_output skb="
        pptr skb
        printf "\n"
        p skb->protocol
    end

    # ────────── 网络设备子系统 ──────────
    break dev_queue_xmit
    commands
        printf "[DEV ] dev_queue_xmit skb="
        pptr skb
        printf "\n"
        p skb->len
        p skb->dev->name
        x/32bx skb->data
    end

    # ────────── 接收路径 ──────────

    break net_rx_action
    commands
        bt
    end
    
    break netif_receive_skb
    commands
        printf "[RX  ] netif_receive_skb skb="
        pptr skb
        printf "\n"
        p skb->len
        x/32bx skb->data
    end

    break ip_rcv
    commands
        printf "[RX  ] ip_rcv skb="
        pptr skb
        printf "\n"
        p skb->protocol
        p skb->hash
    end

    break sock_recvmsg
    commands
        printf "[SOCK] sock_recvmsg called\n"
    end
end



############################################
# 主工作流（保持与原来一致）
############################################
define main_flow
    setup_breaks
    disable                       
    add-symbol-file /home/nudt/client_in_to_out 0x080482b0
    break client_in_to_out.c:main
    commands
        printf "[USER] Hit main()\n"
        stop
    end
    continue
    enable                       
end

main_flow