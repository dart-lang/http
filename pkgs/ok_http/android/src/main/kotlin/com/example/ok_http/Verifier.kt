package com.example.ok_http

import javax.net.ssl.HostnameVerifier
import javax.net.ssl.SSLSession


class Verifier() : HostnameVerifier {

    override fun verify(hostname: String, issuers: SSLSession): Boolean
    {
        println("verify")
        return true;
    }
}