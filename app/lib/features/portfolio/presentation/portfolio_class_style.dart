import 'package:flutter/material.dart';
import 'package:hisaab/features/portfolio/domain/portfolio_class.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';

/// Coloured icon of a portfolio class (FR-16-30).
AppIcon portfolioClassIcon(PortfolioClass c) => switch (c) {
      PortfolioClass.stocks => AppIcons.stocks,
      PortfolioClass.mutualFunds => AppIcons.mutualFunds,
      PortfolioClass.nps => AppIcons.nps,
      PortfolioClass.epfo => AppIcons.epfo,
      PortfolioClass.sukanya => AppIcons.sukanya,
      PortfolioClass.ppf => AppIcons.ppf,
      PortfolioClass.fixedDeposit => AppIcons.fixedDeposit,
      PortfolioClass.gold => AppIcons.gold,
      PortfolioClass.other =>
        const AppIcon(Icons.category_outlined, Color(0xFF9E9E9E)),
    };

/// Class colour (the mockup palette).
Color portfolioClassColor(PortfolioClass c) => portfolioClassIcon(c).color;
