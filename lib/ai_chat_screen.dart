import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  // 1. Setup the Controller to read text
  final TextEditingController _messageController = TextEditingController();
  
  // 2. List to store chat history
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  // 3. Initialize Gemini AI
  // ⚠️ PASTE YOUR API KEY BELOW ⚠️
  final model = GenerativeModel(
    model: 'gemini-3-flash-preview', 
    apiKey: 'AIzaSyAwOflOcFgvXhsc2N7hSCk-DRvF1TP64wc', 
  );

  Future<void> _sendMessage() async {
    final message = _messageController.text;
    if (message.isEmpty) return;

    setState(() {
      // Add user message to screen
      _messages.add({"role": "user", "text": message});
      _isLoading = true;
    });
    
    _messageController.clear();

    try {
      // 4. Send "System Instruction" + User Question
      // We tell the AI how to behave (Persona)
      final prompt = '''
      You are a helpful medical assistant for a Blood Donation App called "Blood Connect". 
      Answer questions about blood donation eligibility, process, and health tips. 
      Keep answers short, friendly, and encouraging.
      User Question: $message
      ''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      setState(() {
        // Add AI response to screen
        _messages.add({"role": "ai", "text": response.text ?? "I didn't understand that."});
        _isLoading = false;
      });
    } catch (e) {
      // 🛑 PRINT THE REAL ERROR TO CONSOLE
      print("==========================================");
      print("AI ERROR: $e");
      print("==========================================");

      setState(() {
        _messages.add({"role": "ai", "text": "Error: Check Console for details."});
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Health Assistant"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- CHAT MESSAGES AREA ---
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.red[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(color: isUser ? Colors.red[900] : Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ),

          // --- TYPING AREA ---
          if (_isLoading) const LinearProgressIndicator(color: Colors.red),
          
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Ask about blood donation...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}