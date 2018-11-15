$ascjson = get-content C:\Git\SMTest\FireLake\root\M2\m2-management\Artifacts\BaselineConfiguration.json | ConvertFrom-Json

$ascjson.baselineRulesets|% {

    $baselinename = $_.baselinename
    
    $_.rules |% {

        $_.baselineRegistryRules  | ConvertTo-Csv -NoTypeInformation >> "$baselinename-Registry.csv"
        $_.baselineAuditPolicyRules | ConvertTo-Csv -NoTypeInformation >> "$baselinename-Audit.csv"
        $_.baselineSecurityPolicyRules | ConvertTo-Csv   -NoTypeInformation >>"$baselinename-Policy.csv"

    }
}

