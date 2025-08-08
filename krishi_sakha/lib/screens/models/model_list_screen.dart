import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:krishi_sakha/models/llm_model.dart';
import 'package:krishi_sakha/providers/model_provider.dart';
import 'package:krishi_sakha/utils/theme/colors.dart';
import 'package:krishi_sakha/screens/chat/local/chat_screen.dart';

import 'package:path/path.dart' as p;

class ModelListScreen extends StatefulWidget {
  const ModelListScreen({super.key});

  @override
  State<ModelListScreen> createState() => _ModelListScreenState();
}

class _ModelListScreenState extends State<ModelListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ModelProvider>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlack,
      appBar: AppBar(
        leading: IconButton(onPressed: (){
          context.pop();
        }, icon: Icon(Icons.arrow_back_ios)),
        backgroundColor: AppColors.primaryBlack,
        foregroundColor: AppColors.primaryWhite,
        title: const Text(
          'Local Assistants',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: Consumer<ModelProvider>(
        builder: (context, modelProvider, child) {
          if (modelProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            );
          }

          if (modelProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    modelProvider.error!,
                    style: const TextStyle(color: AppColors.primaryWhite),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: modelProvider.clearError,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.primaryBlack,
                    ),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            );
          }

          if (modelProvider.models.isEmpty) {
            return _buildEmptyState();
          }

          return _buildModelList(modelProvider);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (){
          _pickModelFile(context);
        },
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.primaryBlack,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Model',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.smart_toy,
              size: 64,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No AI Models',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryWhite,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first GGUF model to get started',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModelList(ModelProvider modelProvider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: modelProvider.models.length,
      itemBuilder: (context, index) {
        final model = modelProvider.models[index];
        return _buildModelCard(model, modelProvider);
      },
    );
  }

  Widget _buildModelCard(LlmModel model, ModelProvider modelProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: model.isActive
              ? AppColors.primaryGreen
              : Colors.grey.withValues(alpha: 0.2),
          width: model.isActive ? 2 : 1,
        ),
        boxShadow: model.isActive
            ? [
                BoxShadow(
                  color: AppColors.primaryGreen.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.smart_toy,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              model.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryWhite,
                              ),
                            ),
                          ),
                          if (model.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryBlack,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last used: ${model.formattedLastUsed}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (value) async {
                    switch (value) {
                      case 'activate':
                        await modelProvider.setActiveModel(model);
                        break;
                      case 'delete':
                        _showDeleteConfirmation(model, modelProvider);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (!model.isActive)
                      const PopupMenuItem(
                        value: 'activate',
                        child: Row(
                          children: [
                            Icon(Icons.play_arrow, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Set Active'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              model.copiedPath,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!model.isActive)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => modelProvider.setActiveModel(model),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.primaryBlack,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Set Active',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                if (model.isActive) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToChat(model),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.primaryBlack,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.chat),
                      label: const Text(
                        'Start Chat',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToChat(LlmModel model) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatScreen(model: model)),
    );
  }


  Future<void> _pickModelFile(BuildContext context) async {
   
    try {
      showDialog(
        
  context: context,
  barrierDismissible: false,
  builder: (context) => const AlertDialog(
    backgroundColor:AppColors.primaryBlack,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: Colors.white,),
        SizedBox(height: 16),
        Text("Adding Model...", style: TextStyle(color: Colors.white)),
      ],
    ),
  ),
);

      FilePickerResult? result ;
      if(!Platform.isAndroid){

       result =  await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gguf'],
      );
      }else{
        result = await FilePicker.platform.pickFiles(
        
      );
      }
if (result == null || result.files.first.path == null) {
        Navigator.pop(context);
        _showError("Please choose the model");
        return;
      }

      final filePath = result.files.first.path!;
      final file = File(filePath);

      if (!await file.exists()) {
Navigator.pop(context);
        _showError('Selected file does not exist');
        return;
      }



// Now perform the model processing
final name = p.basenameWithoutExtension(file.absolute.path);
final modelProvider = Provider.of<ModelProvider>(context, listen: false);
await modelProvider.addModel(name: name, modelPath: filePath);

// Close the dialog after adding
Navigator.of(context).pop();
_showSuccess('Model "$name" added successfully');

    } catch (e) {
      Navigator.pop(context);
      _showError('Failed to add model: $e');
      
    }
  }

  void _showDeleteConfirmation(LlmModel model, ModelProvider modelProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Delete Model',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${model.name}"?',
          style: const TextStyle(color: AppColors.primaryWhite),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await modelProvider.removeModel(model);
                Navigator.of(context).pop();
                _showSuccess('Model deleted successfully');
              } catch (e) {
                _showError('Failed to delete model: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primaryGreen),
    );
  }
}
