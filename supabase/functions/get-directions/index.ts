import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        let origin, destination, key, type, latlng;

        if (req.method === 'GET') {
            const url = new URL(req.url);
            type = url.searchParams.get('type') || 'directions';
            origin = url.searchParams.get('origin');
            destination = url.searchParams.get('destination');
            latlng = url.searchParams.get('latlng');
            key = url.searchParams.get('key');
        } else {
            const body = await req.json().catch(() => ({}));
            type = body.type || 'directions';
            origin = body.origin;
            destination = body.destination;
            latlng = body.latlng;
            key = body.key;
        }

        if (!key) {
            return new Response(
                JSON.stringify({ error: 'Missing required parameter: key' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        let apiUrl = '';
        if (type === 'geocode') {
            if (!latlng) {
                return new Response(
                    JSON.stringify({ error: 'Missing required parameter: latlng for geocode' }),
                    { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
            }
            apiUrl = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${encodeURIComponent(latlng)}&key=${key}`;
        } else {
            if (!origin || !destination) {
                return new Response(
                    JSON.stringify({ error: 'Missing required parameters: origin and destination for directions' }),
                    { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
            }
            apiUrl = `https://maps.googleapis.com/maps/api/directions/json?origin=${encodeURIComponent(origin)}&destination=${encodeURIComponent(destination)}&key=${key}`;
        }

        console.log(`Proxying ${type} request. API URL: ${apiUrl.replace(key, 'REDACTED')}`);
        const response = await fetch(apiUrl);
        const data = await response.json();

        return new Response(
            JSON.stringify(data),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    } catch (error: any) {
        console.error(`Edge Function Error: ${error.message}`);
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
