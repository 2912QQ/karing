# Karing 源码缺口清单（根据调用点统计）

Karing main 分支缺失 61 个 lib/app/utils 文件 + app/local_services/vpn_service.dart + app/private/* + screens/statistics_records_screen.dart，
另外 pubspec 依赖的 ../vpn-service/ 包也没有。下面是被调用最多的接口，接管 Karing 界面层必须按这些签名补齐。

## 1. package:vpn_service (state.dart / vpn_service.dart / proxy_manager.dart)
- enum FlutterVpnServiceState { invalid, disconnected, connecting, connected, reasserting, disconnecting }
- onEventStateChanged: List<FutureOr<void> Function(FlutterVpnServiceState, Map<String,String>)>
  -> 对应 mihomo_core 的 CoreState / MihomoCore.onEventStateChanged

## 2. karing/app/local_services/vpn_service.dart : VPNService（静态方法，调用次数）
getStarted 28 | getTunMode 14 | setCurrentServerForUrltest 13 | setCurrent 11 | onEventStateChanged 7 | getState 7
getCurrentRealTag 6 | isRunAsAdmin 4 | getSystemProxyEnable 4 | stop 3 | getOutboundsWithoutUrltest 3 | currentIsDirect 3
uninit 2 | setSystemProxy 2 | setServer 2 | getTimeoutByOutboundCount 2 | getCurrent 2 | convertErr 2
uninstall, start(timeout), setLaunchAtStartup, reload(timeout), prepareFiles, initABI, init, getUrltests,
getPortsBySetting, getPortsByPrefer, getLaunchAtStartup, getABIs 各 1
- start/reload 返回 ReturnResultError?（null = 成功），可直接由 MihomoCore.start()/reload() 的 CoreError? 转换
- setServer(server, options, SingboxExportType, null, "", savePath) 返回 ReturnResultError?；
  需要把 Karing 的 ProxyConfig 转成 Clash proxy map，再交给 ClashConfigBuilder

## 3. app/utils/clash_api.dart : ClashApi（对应 MihomoApi）
dnsQueryWithDefaultRouter 4 | outboundQuery 2 | getRemoteRulesetsCount 2 | getDelay 2 | getCurrentServerForUrltest 2
updateUrltestCheck, resetOutboundConnections, resetNetwork, getSecret, getRemoteRulesetsStates,
getLogsUrl, getHttpRequestByProxy, getGroupDelayHistory, getConnectionsUrl, dnsQuery 各 1
-> MihomoApi 已有: proxies / proxyDelay / groupDelay / closeAllConnections / dnsQuery / ruleProviders / logsUri / connectionsUri

## 4. 数据模型（最大的缺口）
singbox_outbound.dart 里的 ProxyConfig 被 server_manager.dart（2823 行）到处使用，
并且与 singbox_config_builder.dart（buildOutbound/route/outbounds/ntp/inbounds/endpoints/dns）紧耦合。
没有这两个文件，无法确定字段，只能靠 server_manager.dart 的用法反推。

## 5. 其他被大量引用的工具类
platform_utils 28 | path_utils 28 | proxy_conf_utils 27 | file_utils 22 | log 20 | app_utils 17
app_lifecycle_state_notify 12 | network_utils 11 | url_launcher_utils 10 | http_utils 10 | accessibility_utils 8
