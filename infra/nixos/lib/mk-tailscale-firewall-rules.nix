# mkTailscaleFirewallRules — generate nftables allow+drop rules for Tailscale-only ports.
#
# Usage (via config.nixpi._internal.mkTailscaleFirewallRules):
#   mkRules { port = 8384; }
#   mkRules { port = 22000; protocols = ["tcp" "udp"]; }
{ config }:

{ port, protocols ? ["tcp"] }:

let
  ts = config.nixpi._internal.tailscaleSubnets;
  portStr = toString port;
  ruleLines = builtins.concatMap (proto: [
    "ip saddr ${ts.ipv4} ${proto} dport ${portStr} accept"
    "ip6 saddr ${ts.ipv6} ${proto} dport ${portStr} accept"
  ]) protocols;
  dropLines = map (proto: "${proto} dport ${portStr} drop") protocols;
in
builtins.concatStringsSep "\n" (ruleLines ++ dropLines)
