# CFCat
A CFML wrapper for [The Cat API](https://docs.thecatapi.com/).  
Some people are dog people. Some people are cat people. This wrapper will provide the latter with cats on demand.

*Feel free to use the issue tracker to report bugs or suggest improvements!*

### Acknowledgements

This project borrows heavily from the API frameworks built by [jcberquist](https://github.com/jcberquist), such as [xero-cfml](https://github.com/jcberquist/xero-cfml) and [aws-cfml](https://github.com/jcberquist/aws-cfml). Because it draws on those projects, it is also licensed under the terms of the MIT license.

## Table of Contents

- [Quick Start](#quick-start)
- [`CFCat` Reference Manual](#reference-manual)

## Quick Start
There is only one type of demo: the cat picture demo. So, here you go "Cats As A Service":

```cfc
catapi = new path.to.cfcat.catapi( apiKey = 'xxx' );

randomCat = catapi.getRandom().data;

writeOutput( '<img src="#randomCat.url#">' );
```

## Reference Manual

#### `search( required struct data )`
Search and iterate through all public images. For the `data` arguments, see the [documentation](https://docs.thecatapi.com/api-reference/images/images-search#request-parameters) for available parameters.

#### `searchByCategory( required any category, required struct data )`
Convenience method to define a category of images to search within (i.e. only cats in sunglasses). The `category` argument can be a single id, a comma separated list, or an array of category ids.

#### `getRandom()`
Convenience method that delegates to `search()`, which returns a random image when no parameters are provided

#### `getRandomGif()`
Convenience method that delegates to `search()` and provides the mime type argument. Sometimes you just need cat gifs.

#### `listBreeds()`
List available cat breeds and their properties

#### `listCategories()`
List available cat image categories and their ids, for use in other API methods

---
