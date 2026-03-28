import { SmtpClient } from "https://deno.land/x/smtp@v0.7.0/mod.ts";

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface EmailRequest {
    to: string | string[]
    subject: string
    template?: string
    html?: string
    data?: Record<string, any>
}

Deno.serve(async (req: Request) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const body: EmailRequest = await req.json()
        const { to, subject, template, html, data } = body

        // Validate request
        if (!to || !subject) {
            return new Response(
                JSON.stringify({ error: 'Missing required fields: to, subject' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Get email HTML based on template or use custom HTML
        let emailHtml = html || ''
        if (template && !html) {
            emailHtml = getEmailTemplate(template, data || {})
        }

        const brevoApiKey = Deno.env.get('BREVO_API_KEY')
        if (!brevoApiKey) {
            return new Response(
                JSON.stringify({ error: 'BREVO_API_KEY not configured' }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // For multiple recipients
        const recipients = Array.isArray(to) ? to : [to]
        const sendPromises = recipients.map(recipient =>
            fetch('https://api.brevo.com/v3/smtp/email', {
                method: 'POST',
                headers: {
                    'accept': 'application/json',
                    'api-key': brevoApiKey,
                    'content-type': 'application/json',
                },
                body: JSON.stringify({
                    sender: { name: 'Smart Guardian', email: 'noreply@smartguardian.com' },
                    to: [{ email: recipient }],
                    subject: subject,
                    htmlContent: emailHtml,
                }),
            })
        )

        const results = await Promise.all(sendPromises)
        const allSuccessful = results.every(res => res.ok)

        if (!allSuccessful) {
            const errorDetails = await Promise.all(results.map(async res => res.ok ? null : await res.text()))
            return new Response(
                JSON.stringify({ success: false, error: 'Some emails failed to send', details: errorDetails.filter(d => d) }),
                { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        return new Response(
            JSON.stringify({ success: true, message: 'Email sent successfully via Brevo API' }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    } catch (error: any) {
        return new Response(
            JSON.stringify({ error: error.message || 'Unknown error' }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})

function getEmailTemplate(template: string, data: Record<string, any>): string {
    const formatDate = (ts: any) => {
        try {
            return ts ? new Date(ts).toLocaleString() : new Date().toLocaleString()
        } catch (_) {
            return new Date().toLocaleString()
        }
    }

    const templates: Record<string, (d: any) => string> = {
        welcome: (d) => `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #1900B8;">Welcome to Smart Guardian, ${d.userName || 'User'}! 🛡️</h1>
        <p>Thank you for joining Smart Guardian. Your safety is our priority.</p>
        <p>Get started by completing your profile and setting up emergency contacts.</p>
        <a href="https://smartguardian.com" style="background: #1900B8; color: white; padding: 12px 24px; text-decoration: none; border-radius: 8px; display: inline-block; margin-top: 16px;">
          Open App
        </a>
      </div>
    `,
        sos_alert: (d) => `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 3px solid #ff0000; padding: 20px;">
        <h1 style="color: #ff0000;">🚨 EMERGENCY ALERT</h1>
        <p><strong>${d.userName || 'A user'}</strong> has triggered an SOS alert!</p>
        <p><strong>Location:</strong> ${d.location || 'Unknown'}</p>
        <p><strong>Time:</strong> ${formatDate(d.timestamp)}</p>
        <p style="color: #ff0000; font-weight: bold;">Please check on them immediately!</p>
      </div>
    `,
        journey_notification: (d) => `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #1900B8;">${d.isStarting ? '🛡️ Journey Started' : '✅ Journey Completed'}</h1>
        <p>Hi ${d.userName || 'User'},</p>
        <p>${d.isStarting ? 'Your journey has started. Smart Guardian is now active.' : 'Your journey has been completed safely.'}</p>
        <p><strong>From:</strong> ${d.startLocation || 'N/A'}</p>
        <p><strong>To:</strong> ${d.destination || 'N/A'}</p>
        <p><strong>Time:</strong> ${formatDate(d.timestamp)}</p>
      </div>
    `,
        otp_login: (d) => `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; text-align: center; border: 1px solid #e0e0e0; padding: 40px; border-radius: 12px;">
        <h1 style="color: #1900B8; margin-bottom: 24px;">Verification Code</h1>
        <p style="font-size: 16px; color: #555; margin-bottom: 32px;">Use the code below to sign in to your Smart Guardian account. This code will expire in 10 minutes.</p>
        <div style="background: #f4f7ff; padding: 20px; border-radius: 8px; display: inline-block; margin-bottom: 32px;">
          <span style="font-size: 36px; font-weight: bold; color: #1900B8; letter-spacing: 8px;">${d.otp}</span>
        </div>
        <p style="font-size: 14px; color: #888;">If you didn't request this code, you can safely ignore this email.</p>
      </div>
    `,
    }

    const templateFn = templates[template]
    return templateFn ? templateFn(data) : '<p>Email content</p>'
}
