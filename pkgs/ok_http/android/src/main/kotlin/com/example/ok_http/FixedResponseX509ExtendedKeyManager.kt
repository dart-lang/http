// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

package com.example.ok_http

import java.net.Socket
import java.security.Principal
import java.security.PrivateKey
import java.security.cert.X509Certificate
import javax.net.ssl.SSLEngine
import javax.net.ssl.X509ExtendedKeyManager

/**
 * A `X509ExtendedKeyManager` that always responds with the configured
 * private key, certificate chain, and alias.
 */
class FixedResponseX509ExtendedKeyManager(
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
            keyType: Array<String?>?,
            issuers: Array<Principal?>?,
            engine: SSLEngine?,
    ) = alias

    override fun chooseEngineServerAlias(
            keyType: String?,
            issuers: Array<Principal?>?,
            engine: SSLEngine?
    ) = alias
}
