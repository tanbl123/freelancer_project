import 'package:flutter/material.dart';

class JobPost {
  final String title;
  final double budget;
  final String deadline;
  final List<String> skills;
  final String owner;
  final String description;

  JobPost({
    required this.title,
    required this.budget,
    required this.deadline,
    required this.skills,
    required this.owner,
    required this.description,
  });
}

class ServicePost {
  final String title;
  final double price;
  final String owner;
  final double rating;
  final String description;

  ServicePost({
    required this.title,
    required this.price,
    required this.owner,
    required this.rating,
    required this.description,
  });
}

class Milestone {
  final String title;
  final double amount;
  final String deadline;
  final String status;
  final String description;

  Milestone({
    required this.title,
    required this.amount,
    required this.deadline,
    required this.status,
    required this.description,
  });
}
