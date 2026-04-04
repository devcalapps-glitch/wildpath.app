const PLACES_BASE_URL = 'https://places.googleapis.com/v1';
const GEOCODE_BASE_URL = 'https://maps.googleapis.com/maps/api/geocode/json';

const AUTOCOMPLETE_FIELD_MASK =
  'suggestions.placePrediction.placeId,' +
  'suggestions.placePrediction.text.text,' +
  'suggestions.placePrediction.structuredFormat.mainText.text,' +
  'suggestions.placePrediction.structuredFormat.secondaryText.text';

const SEARCH_TEXT_FIELD_MASK =
  'places.id,places.displayName,places.formattedAddress,places.primaryType';

const PLACE_DETAILS_FIELD_MASK =
  'formattedAddress,addressComponents,location,id,types,displayName';

function json(statusCode, body) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    },
    body: JSON.stringify(body),
  };
}

function sanitizeText(value) {
  return typeof value === 'string' ? value.trim() : '';
}

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return json(405, {error: 'Method not allowed'});
  }

  const apiKey = sanitizeText(process.env.MAPS_API_KEY);
  if (!apiKey) {
    return json(500, {error: 'MAPS_API_KEY is not configured'});
  }

  let payload;
  try {
    payload = JSON.parse(event.body || '{}');
  } catch (_) {
    return json(400, {error: 'Invalid JSON body'});
  }

  const operation = sanitizeText(payload.operation);
  if (!operation) {
    return json(400, {error: 'Missing operation'});
  }

  try {
    let response;

    switch (operation) {
      case 'autocomplete': {
        const input = sanitizeText(payload.input);
        const includedPrimaryTypes = Array.isArray(payload.includedPrimaryTypes)
          ? payload.includedPrimaryTypes.filter((value) => typeof value === 'string')
          : [];
        const sessionToken = sanitizeText(payload.sessionToken);

        if (!input) {
          return json(400, {error: 'Missing input'});
        }

        response = await fetch(`${PLACES_BASE_URL}/places:autocomplete`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask': AUTOCOMPLETE_FIELD_MASK,
          },
          body: JSON.stringify({
            input,
            sessionToken: sessionToken || undefined,
            includeQueryPredictions: false,
            includePureServiceAreaBusinesses: false,
            includedPrimaryTypes,
          }),
        });
        break;
      }

      case 'searchText': {
        const textQuery = sanitizeText(payload.textQuery);
        const pageSize = Number(payload.pageSize) || 5;
        const strictTypeFiltering = payload.strictTypeFiltering == true;
        const includedType = sanitizeText(payload.includedType);
        const sessionToken = sanitizeText(payload.sessionToken);

        if (!textQuery) {
          return json(400, {error: 'Missing textQuery'});
        }

        response = await fetch(`${PLACES_BASE_URL}/places:searchText`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask': SEARCH_TEXT_FIELD_MASK,
            ...(sessionToken ? {'X-Goog-Session-Token': sessionToken} : {}),
          },
          body: JSON.stringify({
            textQuery,
            pageSize,
            strictTypeFiltering,
            includedType: includedType || undefined,
            rankPreference: 'RELEVANCE',
          }),
        });
        break;
      }

      case 'placeDetails': {
        const placeId = sanitizeText(payload.placeId);
        const sessionToken = sanitizeText(payload.sessionToken);

        if (!placeId) {
          return json(400, {error: 'Missing placeId'});
        }

        response = await fetch(
          `${PLACES_BASE_URL}/places/${encodeURIComponent(placeId)}`,
          {
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask': PLACE_DETAILS_FIELD_MASK,
              ...(sessionToken ? {'X-Goog-Session-Token': sessionToken} : {}),
            },
          },
        );
        break;
      }

      case 'reverseGeocode': {
        const lat = Number(payload.lat);
        const lng = Number(payload.lng);
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
          return json(400, {error: 'Missing lat/lng'});
        }

        const url = new URL(GEOCODE_BASE_URL);
        url.searchParams.set('latlng', `${lat},${lng}`);
        url.searchParams.set('key', apiKey);
        response = await fetch(url);
        break;
      }

      default:
        return json(400, {error: 'Unsupported operation'});
    }

    const text = await response.text();
    return {
      statusCode: response.status,
      headers: {
        'Content-Type': response.headers.get('content-type') || 'application/json',
        'Cache-Control': 'no-store',
      },
      body: text,
    };
  } catch (error) {
    return json(502, {
      error: 'Upstream request failed',
      detail: error instanceof Error ? error.message : String(error),
    });
  }
};
