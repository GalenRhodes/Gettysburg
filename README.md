# Gettysburg

This is an implementation of the SAX interface.

## API Documentation

Documentation of the API can be found here: [Gettysburg API](http://galenrhodes.com/Gettysburg/)

## A note on Character Encodings

The [XML specification states](https://www.w3.org/TR/REC-xml/#charencoding):

> Entities encoded in UTF-16 must and entities encoded in UTF-8 may begin with the Byte Order Mark described by Annex H of [ISO/IEC 10646:2000], section 16.8 of [Unicode](https://home.unicode.org) (the ZERO WIDTH NO-BREAK SPACE character, #xFEFF).
> This is an encoding signature, not part of either the markup or the character data of the XML document. XML processors must be able to use this character to differentiate between UTF-8 and UTF-16 encoded documents.
>
> If the replacement text of an external entity is to begin with the character U+FEFF, and no text declaration is present, then a Byte Order Mark MUST be present, whether the entity is encoded in UTF-8 or UTF-16.
>
> Although an XML processor is required to read only entities in the UTF-8 and UTF-16 encodings, it is recognized that other encodings are used around the world, and it may be desired for XML processors to read entities that use them. In the absence of external character encoding information (such as MIME headers), parsed entities which are stored in an encoding other than UTF-8 or UTF-16 must begin with a text declaration (see 4.3.1 The Text Declaration) containing an encoding declaration

In short, we're supposed to start out assuming the possibility of UTF-8 or UTF-16 and then if there is an XML Declaration we should see the encoding field in that, if it has one, to determine the actual character encoding used in the document.

Gettysburg will actually attempt to detect and handle UTF-8, UTF-16, **and UTF-32** character encodings (with or without a byte-order-mark). Gettysburg will also handle other character encodings as long as there is an [XML Declaration](https://www.w3.org/TR/REC-xml/#sec-prolog-dtd) in the document specifying what the proper character encoding should be. That XML Declaration should be in either UTF-8, UTF-16, or UTF-32 encoding. Also, the encoding specified in the XML Declaration should match the byte-width of the XML Declaration itself. In other words, don't start off with UTF-16 and then specify UTF-8 in the XML Declaration. Even if everything AFTER the XML Declaration is in UTF-8 this is considered a malformed and invalid XML document.  Gettysburg will also honor a MIME header which indicates character encoding if one is present.

The same applies to external entities and DTDs (which are considered a special case of external entities). Character encodings other than UTF-8, UTF-16, and UTF-32 will be supported as long as there is a [Text Declaration (XML specification sections 4.3.1 - 4.3.3)](https://www.w3.org/TR/REC-xml/#sec-TextDecl) at the beginning of the external entity or DTD.

