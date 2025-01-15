package com.example.ok_http

import java.net.Socket
import java.security.Principal
import java.security.PrivateKey
import java.security.cert.X509Certificate
import javax.net.ssl.SSLEngine
import javax.net.ssl.X509ExtendedKeyManager

class X509Foo(
        private val certificateChain: Array<X509Certificate>,
        private val privateKey: PrivateKey,
        private val alias: String,
) : X509ExtendedKeyManager() {

    override fun getClientAliases(keyType: String, issuers: Array<Principal>?) = arrayOf(alias)

    override fun chooseClientAlias(
            keyType: Array<String>,
            issuers: Array<Principal>?,
            socket: Socket?,
    ) = alias

    override fun getServerAliases(keyType: String, issuers: Array<Principal>?) = arrayOf(alias)

    override fun chooseServerAlias(
            keyType: String,
            issuers: Array<Principal>?,
            socket: Socket?,
    ) = alias

    override fun getCertificateChain(alias: String) = certificateChain

    override fun getPrivateKey(alias: String) = privateKey

    override fun chooseEngineClientAlias(
            keyType: Array<String>?,
            issuers: Array<Principal>?,
            engine: SSLEngine?,
    ) = alias

    override fun chooseEngineServerAlias(
            keyType: String?,
            issuers: Array<Principal>?,
            engine: SSLEngine
    ) = alias
}
