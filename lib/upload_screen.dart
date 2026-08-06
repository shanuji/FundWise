// Modify ONLY the parsing logic inside _uploadAndParse()
      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        
        if (widget.onParseSuccess != null) {
          // FIXED: Extract transactions safely, even if nested inside a 'data' object
          var root = responseData['data'] ?? responseData;
          List<dynamic> transactions = root['transactions'] ?? root['cas_transactions'] ?? root['history'] ?? []; 
          widget.onParseSuccess!(responseData, transactions);
        }
// ... (Keep the rest exactly as it is)
