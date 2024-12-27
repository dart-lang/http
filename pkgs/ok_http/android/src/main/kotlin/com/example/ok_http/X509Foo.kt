package com.example.ok_http

import javax.net.ssl.X509ExtendedKeyManager
import javax.net.ssl.SSLEngine
import java.net.Socket
import java.security.Principal
import java.security.PrivateKey
import java.security.cert.X509Certificate
import android.util.Log

class X509Foo : X509ExtendedKeyManager() {
    init {
        Log.e("OKHTTP", "X509Foo constructor")
    }

    override fun getClientAliases(keyType: String, issuers: Array<Principal>?): Array<String>
    {
        Log.e("OKHTTP", "getClientAliases")
        return arrayOf("Foo")
    }

    override fun chooseClientAlias(
    keyType: Array<String>,
    issuers: Array<Principal>?,
    socket: Socket?,
  ): String  { 
    Log.e("OKHTTP", "chooseClientAlias")
        return "Foo";
    }

    override fun getServerAliases(keyType: String, issuers: Array<Principal>?): Array<String> { 
        Log.e("OKHTTP", "getServerAliases")
        return arrayOf("Foo")
    }

    override fun chooseServerAlias(
    keyType: String,
    issuers: Array<Principal>?,
    socket: Socket?,
  ): String { 
    Log.e("OKHTTP", "chooseServerAlias")
        return "Foo"
    }

    override fun getCertificateChain(alias: String): Array<X509Certificate>? {
        Log.e("OKHTTP", "getCertificateChain")
        return arrayOf()
    }


    override fun getPrivateKey(alias: String): PrivateKey? {
        Log.e("OKHTTP", "getPrivateKey");
        return null
    }

    override fun chooseEngineClientAlias(
        keyType: Array<String>,
        issuers: Array<Principal>?,
        engine: SSLEngine?,
      ): String {
        Log.e("OKHTTP", "chooseEngineClientAlias");
        return "Hello";
    }

    override fun chooseEngineServerAlias(keyType: String, issuers: Array<Principal>?, engine: SSLEngine) : String {
        Log.e("OKHTTP", "chooseEngineServerAlias");
        return "Hello";
    }

}