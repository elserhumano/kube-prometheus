{
  _config+:: {
    eks: {
      minimumAvailableIPs: 10,
      minimumAvailableIPsTime: '10m',
    },
  },
  prometheus+: {
    serviceMonitorCoreDNS+: {
      spec+: {
        endpoints: [
          {
            bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
            interval: '15s',
            targetPort: 9153,
          },
        ],
      },
    },
    AwsEksCniMetricService: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'aws-node',
        namespace: 'kube-system',
        labels: { 'app.kubernetes.io/name': 'aws-node' },
      },
      spec: {
        ports: [
          { name: 'cni-metrics-port', port: 61678, targetPort: 61678 },
        ],
        selector: { 'app.kubernetes.io/name': 'aws-node' },
        clusterIP: 'None',
      },
    },

    serviceMonitorAwsEksCNI: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata: {
        name: 'awsekscni',
        namespace: $._config.namespace,
        labels: {
          'app.kubernetes.io/name': 'eks-cni',
        },
      },
      spec: {
        jobLabel: 'app.kubernetes.io/name',
        selector: {
          matchLabels: {
            'app.kubernetes.io/name': 'aws-node',
          },
        },
        namespaceSelector: {
          matchNames: [
            'kube-system',
          ],
        },
        endpoints: [
          {
            port: 'cni-metrics-port',
            interval: '30s',
            path: '/metrics',
          },
        ],
      },
    },
  },
  prometheusRules+: {
    groups+: [
      {
        name: 'kube-prometheus-eks.rules',
        rules: [
          {
            expr: 'sum by(instance) (awscni_ip_max) - sum by(instance) (awscni_assigned_ip_addresses) < %s' % $._config.eks.minimumAvailableIPs,
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: 'Instance {{ $labels.instance }} has less than 10 IPs available.',
            },
            'for': $._config.eks.minimumAvailableIPsTime,
            alert: 'EksAvailableIPs',
          },
        ],
      },
    ],
  },
}
