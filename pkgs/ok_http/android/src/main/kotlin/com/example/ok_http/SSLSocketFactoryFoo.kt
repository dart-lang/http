package com.example.ok_http

import javax.net.ssl.X509ExtendedKeyManager
import java.net.Socket
import java.net.InetAddress
import java.security.Principal
import java.security.PrivateKey
import java.security.cert.X509Certificate
import javax.net.ssl.SSLSocketFactory

class SSLSocketFactoryFoo() : SSLSocketFactory() {

    override fun createSocket() : Socket {
        println("SSLSocketFactoryFoo.createSocket")
        return SSLSocketFactory.getDefault().createSocket();
    }

    override fun createSocket(p0: String, p1: Int): Socket { 
        println("SSLSocketFactoryFoo.createSocket")
        return SSLSocketFactory.getDefault().createSocket(p0, p1);
    }

    override fun createSocket(p0: String, p1: Int, p2: InetAddress, p3: Int): Socket { 
        println("SSLSocketFactoryFoo.createSocket")
        return SSLSocketFactory.getDefault().createSocket(p0, p1, p2, p3);

    }

    override fun createSocket(p0: InetAddress, p1: Int): Socket { 
        println("SSLSocketFactoryFoo.createSocket")
        return SSLSocketFactory.getDefault().createSocket(p0, p1);
    }

    override fun createSocket(p0: InetAddress, p1: Int, p2: InetAddress, p3: Int): Socket { 
        println("SSLSocketFactoryFoo.createSocket")
        return SSLSocketFactory.getDefault().createSocket(p0, p1, p2, p3);
    }

    override fun createSocket(p0: Socket, p1: String, p2: Int, p3: Boolean): Socket { 
        println("SSLSocketFactoryFoo.createSocket")
        return (SSLSocketFactory.getDefault() as SSLSocketFactory).createSocket(p0, p1, p2, p3);

    }

    override fun getDefaultCipherSuites(): Array<(String)> { 
        println("SSLSocketFactoryFoo.getDefaultCipherSuites")
        return (SSLSocketFactory.getDefault() as SSLSocketFactory).defaultCipherSuites;
    }

    override fun getSupportedCipherSuites(): Array<(String)> { 
        println("SSLSocketFactoryFoo.getSupportedCipherSuites")
        return (SSLSocketFactory.getDefault() as SSLSocketFactory).supportedCipherSuites;

    }

}