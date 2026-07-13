resource "kubernetes_config_map_v1" "k6_script" {
  metadata {
    name      = "k6-hpa-script"
    namespace = kubernetes_namespace_v1.web.metadata[0].name
  }

  data = {
    "test.js" = <<-JAVASCRIPT
      import http from "k6/http";
      import { check } from "k6";

      export const options = {
        discardResponseBodies: true,

        scenarios: {
          hpa_cycle: {
            executor: "ramping-arrival-rate",
            startRate: 1,
            timeUnit: "1s",
            preAllocatedVUs: 30,
            maxVUs: 100,

            // Establish an idle baseline, saturate the first Pod long enough
            // for Metrics Server and HPA to react, then reduce traffic long
            // enough to observe the configured 60-second scale-down window.
            stages: [
              { target: 1,  duration: "30s"  },
              { target: 25, duration: "45s"  },
              { target: 25, duration: "120s" },
              { target: 1,  duration: "30s"  },
              { target: 1,  duration: "150s" },
            ],
          },
        },

        thresholds: {
          http_req_failed: ["rate<0.05"],
        },
      };

      export default function () {
        const response = http.get(`$${__ENV.TARGET_URL}/?work=5000000`, {
          tags: { endpoint: "web" },
          timeout: "10s",
        });

        check(response, {
          "web returned HTTP 200": (r) => r.status === 200,
        });
      }
    JAVASCRIPT
  }
}
