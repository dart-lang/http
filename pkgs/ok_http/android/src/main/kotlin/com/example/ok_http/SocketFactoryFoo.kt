package com.example.ok_http

import javax.net.ssl.X509ExtendedKeyManager
import java.net.Socket
import java.net.InetAddress
import java.security.Principal
import java.security.PrivateKey
import java.security.cert.X509Certificate
import javax.net.SocketFactory

class SocketFactoryFoo() : SocketFactory() {

    override fun createSocket() : Socket {
        println("createSocket")
        return SocketFactory.getDefault().createSocket();
    }

    override fun createSocket(p0: String, p1: Int): Socket { 
        println("createSocket")
        return SocketFactory.getDefault().createSocket(p0, p1);
    }

    override fun createSocket(p0: String, p1: Int, p2: InetAddress, p3: Int): Socket { 
        println("createSocket")
        return SocketFactory.getDefault().createSocket(p0, p1, p2, p3);

    }

    override fun createSocket(p0: InetAddress, p1: Int): Socket { 
        println("createSocket")
        return SocketFactory.getDefault().createSocket(p0, p1);
    }

    override fun createSocket(p0: InetAddress, p1: Int, p2: InetAddress, p3: Int): Socket { 
        println("createSocket")
        return SocketFactory.getDefault().createSocket(p0, p1, p2, p3);
    }
}