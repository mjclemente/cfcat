/**
* CFCat
* Copyright 2019  Matthew J. Clemente, John Berquist
* Licensed under MIT (https://mit-license.org)
*/
component displayname="CFCat"  {

  variables._cfcat_version = '0.6.0';

  public any function init(
    string apiKey = '',
    string baseUrl = "https://api.thecatapi.com/v1",
    boolean includeRaw = false ) {

    structAppend( variables, arguments );

    //map sensitive args to env variables or java system props
    var secrets = {
      'apiKey': 'CATAPI_API_KEY'
    };
    var system = createObject( 'java', 'java.lang.System' );

    for ( var key in secrets ) {
      //arguments are top priority
      if ( variables[ key ].len() ) continue;

      //check environment variables
      var envValue = system.getenv( secrets[ key ] );
      if ( !isNull( envValue ) && envValue.len() ) {
        variables[ key ] = envValue;
        continue;
      }

      //check java system properties
      var propValue = system.getProperty( secrets[ key ] );
      if ( !isNull( propValue ) && propValue.len() ) {
        variables[ key ] = propValue;
      }
    }

    //declare file fields to be handled via multipart/form-data **Important** this is not applicable if payload is application/json
    variables.fileFields = [];

    return this;
  }

  /**
  * https://docs.thecatapi.com/api-reference/images/images-search
  * @hint Search and iterate through all public images
    @data see documentation for available parameters (https://docs.thecatapi.com/api-reference/images/images-search#request-parameters)
  */
  public struct function search( required struct data ) {
    return apiCall( 'GET', '/images/search', data );
  }

  /**
  * https://docs.thecatapi.com/api-reference/images/images-search
  * https://docs.thecatapi.com/example-by-category
  * @hint Convenience method to define a category of images to search within (i.e. only cats in sunglasses)
  * @category can be a single id, a comma separated list, or an array of category ids.
    @data see documentation for available parameters (https://docs.thecatapi.com/api-reference/images/images-search#request-parameters)
  */
  public struct function searchByCategory( required any category, required struct data ) {
    var params = data;
    var categoryIds = [];
    if( isArray( category ) ) {
      categoryIds = category;
    } else {
      categoryIds = listToArray( category );
    }

    params[ 'category_ids' ] = categoryIds;
    return apiCall( 'GET', '/images/search', params );
  }

  /**
  * @hint Convenience method that delegates to `search()`, which returns a random image when no parameters are provided
  */
  public struct function getRandom() {
    var randomImage = search( {} );
    if( isArray( randomImage.data ) && randomImage.data.len() > 0 ) {
      randomImage.data = randomImage.data[ 1 ];
    }

    return randomImage;
  }

  /**
  * https://docs.thecatapi.com/example-by-type
  * @hint Convenience method that delegates to `search()` and provides the mime type argument. Sometimes you just need cat gifs.
  */
  public struct function getRandomGif() {
    var randomImage = search( { "mime_types" = [ "gif" ] } );
    if( isArray( randomImage.data ) && randomImage.data.len() > 0 ) {
      randomImage.data = randomImage.data[ 1 ];
    }

    return randomImage;
  }

  /**
  * https://docs.thecatapi.com/api-reference/breeds/breeds-list
  * @hint List available cat breeds and their properties
  */
  public struct function listBreeds() {
    return apiCall( 'GET', '/breeds' );
  }

  /**
  * https://docs.thecatapi.com/api-reference/categories/categories-list
  * @hint List available cat image categories and their ids, for use in other API methods
  */
  public struct function listCategories( numeric limit, numeric page ) {
    var params = {};
    if( !isNull( limit ) )
      params[ 'limit' ] = limit;

    if( !isNull( page) )
      params[ 'page' ] = page;

    return apiCall( 'GET', '/categories', params );
  }

  // PRIVATE FUNCTIONS
  private struct function apiCall(
    required string httpMethod,
    required string path,
    struct queryParams = { },
    any payload = '',
    struct headers = { } )  {

    var fullApiPath = variables.baseUrl & path;
    var requestHeaders = getBaseHttpHeaders();
    requestHeaders.append( headers, true );

    var requestStart = getTickCount();
    var apiResponse = makeHttpRequest( httpMethod = httpMethod, path = fullApiPath, queryParams = queryParams, headers = requestHeaders, payload = payload );

    var result = {
      'responseTime' = getTickCount() - requestStart,
      'statusCode' = listFirst( apiResponse.statuscode, " " ),
      'statusText' = listRest( apiResponse.statuscode, " " ),
      'headers' = apiResponse.responseheader
    };

    var parsedFileContent = {};

    // Handle response based on mimetype
    var mimeType = apiResponse.mimetype ?: requestHeaders[ 'Content-Type' ];

    if ( mimeType == 'application/json' && isJson( apiResponse.fileContent ) ) {
      parsedFileContent = deserializeJSON( apiResponse.fileContent );
    } else if ( mimeType.listLast( '/' ) == 'xml' && isXml( apiResponse.fileContent ) ) {
      parsedFileContent = xmlToStruct( apiResponse.fileContent );
    } else {
      parsedFileContent = apiResponse.fileContent;
    }

    //can be customized by API integration for how errors are returned
    //if ( result.statusCode >= 400 ) {}

    //stored in data, because some responses are arrays and others are structs
    result[ 'data' ] = parsedFileContent;

    if ( variables.includeRaw ) {
      result[ 'raw' ] = {
        'method' : ucase( httpMethod ),
        'path' : fullApiPath,
        'params' : parseQueryParams( queryParams ),
        'payload' : parseBody( payload ),
        'response' : apiResponse.fileContent
      };
    }

    return result;
  }

  private struct function getBaseHttpHeaders() {
    return {
      'Accept' : 'application/json',
      'Content-Type' : 'application/json',
      'x-api-key' : '#variables.apiKey#',
      'User-Agent' : 'CFCat/#variables._cfcat_version# (ColdFusion)'
    };
  }

  private any function makeHttpRequest(
    required string httpMethod,
    required string path,
    struct queryParams = { },
    struct headers = { },
    any payload = ''
  ) {
    var result = '';

    var fullPath = path & ( !queryParams.isEmpty()
      ? ( '?' & parseQueryParams( queryParams, false ) )
      : '' );

    var requestHeaders = parseHeaders( headers );

    cfhttp( url = fullPath, method = httpMethod,  result = 'result' ) {

      if ( isJsonPayload( headers ) ) {

        var requestPayload = parseBody( payload );
        if ( isJSON( requestPayload ) )
          cfhttpparam( type = "body", value = requestPayload );

      } else if ( isFormPayload( headers ) ) {

        headers.delete( 'Content-Type' ); //Content Type added automatically by cfhttppparam

        for ( var param in payload ) {
          if ( !variables.fileFields.contains( param ) )
            cfhttpparam( type = 'formfield', name = param, value = payload[ param ] );
          else
            cfhttpparam( type = 'file', name = param, file = payload[ param ] );
        }

      }

      //handled last, to account for possible Content-Type header correction for forms
      var requestHeaders = parseHeaders( headers );
      for ( var header in requestHeaders ) {
        cfhttpparam( type = "header", name = header.name, value = header.value );
      }

    }
    return result;
  }

  /**
  * @hint convert the headers from a struct to an array
  */
  private array function parseHeaders( required struct headers ) {
    var sortedKeyArray = headers.keyArray();
    sortedKeyArray.sort( 'textnocase' );
    var processedHeaders = sortedKeyArray.map(
      function( key ) {
        return { name: key, value: trim( headers[ key ] ) };
      }
    );
    return processedHeaders;
  }

  /**
  * @hint converts the queryparam struct to a string, with optional encoding and the possibility for empty values being pass through as well
  */
  private string function parseQueryParams( required struct queryParams, boolean encodeQueryParams = true, boolean includeEmptyValues = true ) {
    var sortedKeyArray = queryParams.keyArray();
    sortedKeyArray.sort( 'text' );

    var queryString = sortedKeyArray.reduce(
      function( queryString, queryParamKey ) {
        var encodedKey = encodeQueryParams
          ? encodeUrl( queryParamKey )
          : queryParamKey;
        if ( !isArray( queryParams[ queryParamKey ] ) ) {
          var encodedValue = encodeQueryParams && len( queryParams[ queryParamKey ] )
            ? encodeUrl( queryParams[ queryParamKey ] )
            : queryParams[ queryParamKey ];
        } else {
          var encodedValue = encodeQueryParams && ArrayLen( queryParams[ queryParamKey ] )
            ?  encodeUrl( serializeJSON( queryParams[ queryParamKey ] ) )
            : queryParams[ queryParamKey ].toList();
          }
        return queryString.listAppend( encodedKey & ( includeEmptyValues || len( encodedValue ) ? ( '=' & encodedValue ) : '' ), '&' );
      }, ''
    );

    return queryString.len() ? queryString : '';
  }

  private string function parseBody( required any body ) {
    if ( isStruct( body ) || isArray( body ) )
      return serializeJson( body );
    else if ( isJson( body ) )
      return body;
    else
      return '';
  }

  private string function encodeUrl( required string str, boolean encodeSlash = true ) {
    var result = replacelist( urlEncodedFormat( str, 'utf-8' ), '%2D,%2E,%5F,%7E', '-,.,_,~' );
    if ( !encodeSlash ) result = replace( result, '%2F', '/', 'all' );

    return result;
  }

  /**
  * @hint helper to determine if body should be sent as JSON
  */
  private boolean function isJsonPayload( required struct headers ) {
    return headers[ 'Content-Type' ] == 'application/json';
  }

  /**
  * @hint helper to determine if body should be sent as form params
  */
  private boolean function isFormPayload( required struct headers ) {
    return arrayContains( [ 'application/x-www-form-urlencoded', 'multipart/form-data' ], headers[ 'Content-Type' ] );
  }

  /**
  *
  * Based on an (old) blog post and UDF from Raymond Camden
  * https://www.raymondcamden.com/2012/01/04/Converting-XML-to-JSON-My-exploration-into-madness/
  *
  */
  private struct function xmlToStruct( required any x ) {

    if ( isSimpleValue( x ) && isXml( x ) )
      x = xmlParse( x );

    var s = {};

    if ( xmlGetNodeType( x ) == "DOCUMENT_NODE" ) {
      s[ structKeyList( x ) ] = xmlToStruct( x[ structKeyList( x ) ] );
    }

    if ( structKeyExists( x, "xmlAttributes" ) && !structIsEmpty( x.xmlAttributes ) ) {
      s.attributes = {};
      for ( var item in x.xmlAttributes ) {
        s.attributes[ item ] = x.xmlAttributes[ item ];
      }
    }

    if ( structKeyExists( x, 'xmlText' ) && x.xmlText.trim().len() )
      s.value = x.xmlText;

    if ( structKeyExists( x, "xmlChildren" ) ) {

      for ( var xmlChild in x.xmlChildren ) {
        if ( structKeyExists( s, xmlChild.xmlname ) ) {

          if ( !isArray( s[ xmlChild.xmlname ] ) ) {
            var temp = s[ xmlChild.xmlname ];
            s[ xmlChild.xmlname ] = [ temp ];
          }

          arrayAppend( s[ xmlChild.xmlname ], xmlToStruct( xmlChild ) );

        } else {

          if ( structKeyExists( xmlChild, "xmlChildren" ) && arrayLen( xmlChild.xmlChildren ) ) {
              s[ xmlChild.xmlName ] = xmlToStruct( xmlChild );
           } else if ( structKeyExists( xmlChild, "xmlAttributes" ) && !structIsEmpty( xmlChild.xmlAttributes ) ) {
            s[ xmlChild.xmlName ] = xmlToStruct( xmlChild );
          } else {
            s[ xmlChild.xmlName ] = xmlChild.xmlText;
          }

        }

      }
    }

    return s;
  }

}