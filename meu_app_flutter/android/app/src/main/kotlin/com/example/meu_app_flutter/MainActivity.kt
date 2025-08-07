package com.example.meu_app_flutter

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "network_control"
    private lateinit var connectivityManager: ConnectivityManager
    private var ethernetNetwork: Network? = null
    private var wifiNetwork: Network? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "forceEthernetNetwork" -> {
                    val success = forceEthernetNetwork()
                    result.success(success)
                }
                "forceWifiNetwork" -> {
                    val success = forceWifiNetwork()
                    result.success(success)
                }
                "getNetworkInfo" -> {
                    val networkInfo = getNetworkInfo()
                    result.success(networkInfo)
                }
                "isNetworkControlSupported" -> {
                    val supported = isNetworkControlSupported()
                    result.success(supported)
                }
                "testNetworkConnectivity" -> {
                    val networkType = call.argument<String>("networkType") ?: "unknown"
                    val connectivity = testNetworkConnectivity(networkType)
                    result.success(connectivity)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun forceEthernetNetwork(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                ethernetNetwork?.let { network ->
                    connectivityManager.bindProcessToNetwork(network)
                    Log.d("MainActivity", "Rede Ethernet forçada para o processo")
                    true
                } ?: run {
                    Log.w("MainActivity", "Rede Ethernet não encontrada")
                    false
                }
            } else {
                Log.w("MainActivity", "API não suportada para Android < 6.0")
                false
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Erro ao forçar rede Ethernet: ${e.message}")
            false
        }
    }

    private fun forceWifiNetwork(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                wifiNetwork?.let { network ->
                    connectivityManager.bindProcessToNetwork(network)
                    Log.d("MainActivity", "Rede Wi-Fi forçada para o processo")
                    true
                } ?: run {
                    Log.w("MainActivity", "Rede Wi-Fi não encontrada")
                    false
                }
            } else {
                Log.w("MainActivity", "API não suportada para Android < 6.0")
                false
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Erro ao forçar rede Wi-Fi: ${e.message}")
            false
        }
    }

    private fun getNetworkInfo(): Map<String, Any> {
        val info = mutableMapOf<String, Any>()
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val networks = connectivityManager.allNetworks
                var hasEthernet = false
                var hasWifi = false
                
                for (network in networks) {
                    val capabilities = connectivityManager.getNetworkCapabilities(network)
                    capabilities?.let { caps ->
                        when {
                            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> {
                                hasEthernet = true
                                ethernetNetwork = network
                                Log.d("MainActivity", "Rede Ethernet encontrada")
                            }
                            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> {
                                hasWifi = true
                                wifiNetwork = network
                                Log.d("MainActivity", "Rede Wi-Fi encontrada")
                            }
                            else -> {
                                // Outros tipos de rede (celular, etc.) - ignorar
                            }
                        }
                    }
                }
                
                info["hasEthernet"] = hasEthernet
                info["hasWifi"] = hasWifi
                info["ethernetNetwork"] = ethernetNetwork != null
                info["wifiNetwork"] = wifiNetwork != null
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Erro ao obter informações de rede: ${e.message}")
        }
        
        return info
    }

    private fun isNetworkControlSupported(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
    }

    private fun testNetworkConnectivity(networkType: String): Boolean {
        return try {
            val network = when (networkType) {
                "ethernet" -> ethernetNetwork
                "wifi" -> wifiNetwork
                else -> null
            }
            
            network?.let { net ->
                val capabilities = connectivityManager.getNetworkCapabilities(net)
                capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) ?: false
            } ?: false
        } catch (e: Exception) {
            Log.e("MainActivity", "Erro ao testar conectividade: ${e.message}")
            false
        }
    }
}
