// Modify ONLY the build method inside _SettingsTabState
  @override
  Widget build(BuildContext context) {
    // FIXED: Search the ENTIRE parsedData map for tax info, not just portfolio_summary
    final portfolioSummary = widget.parsedData['portfolio_summary'] ?? {};
    final taxSummary = widget.parsedData['tax_summary'] ?? widget.parsedData['taxes'] ?? widget.parsedData['capital_gains'] ?? {};
    
    // Check both locations
    final double stcgProfit = (taxSummary['stcg'] ?? taxSummary['short_term'] ?? portfolioSummary['stcg'] ?? 0.0).toDouble();
    final double ltcgProfit = (taxSummary['ltcg'] ?? taxSummary['long_term'] ?? portfolioSummary['ltcg'] ?? 0.0).toDouble();

// ... (Keep the rest of the build method exactly as it is)
