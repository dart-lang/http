package com.example.ok_http

import javax.net.ssl.X509ExtendedKeyManager
import java.net.Socket
import java.security.Principal
import java.security.PrivateKey
import java.security.cert.X509Certificate

class X509Foo : X509ExtendedKeyManager() {

    override fun getClientAliases(keyType: String, issuers: Array<Principal>?): Array<String>
    {
        println("getClientAliases")
        return arrayOf("Foo")
    }

    override fun chooseClientAlias(
    keyType: Array<String>,
    issuers: Array<Principal>?,
    socket: Socket?,
  ): String  { 
        println("chooseClientAlias")
        return "Foo";
    }

    override fun getServerAliases(keyType: String, issuers: Array<Principal>?): Array<String> { 
        println("getServerAliases")
        return arrayOf("Foo")
    }

    override fun chooseServerAlias(
    keyType: String,
    issuers: Array<Principal>?,
    socket: Socket?,
  ): String { 
        println("chooseServerAlias")
        return "Foo"
    }

    override fun getCertificateChain(alias: String): Array<X509Certificate>? {
        println("getCertificateChain")
        return arrayOf()
    }


    override fun getPrivateKey(alias: String): PrivateKey? {
        println("getPrivateKey");
        return null
    }

}