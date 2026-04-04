import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'anime_fox_view.dart';

Future<ui.Image> widgetToImage(int rating, int animationPhase) async {
  // Create a GlobalKey for the RepaintBoundary
  final GlobalKey repaintBoundaryKey = GlobalKey();

  // Create the widget tree with RepaintBoundary.
  // The tree is attached to a synthetic render pipeline below — the variable
  // is intentionally unused as a reference after creation.
  RepaintBoundary(
    key: repaintBoundaryKey,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: SizedBox(
                width: 110,
                height: 110,
                child: AnimeFoxView(
                    rating: rating, animationPhase: animationPhase),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  // Create a BuildOwner and PipelineOwner for rendering
  final BuildOwner buildOwner = BuildOwner();
  final PipelineOwner pipelineOwner = PipelineOwner();

  // Get the FlutterView from PlatformDispatcher
  final ui.FlutterView flutterView = ui.PlatformDispatcher.instance.views.first;

  // Create the RenderView with minimal configuration
  final RenderView renderView = RenderView(
    view: flutterView,
    configuration: ViewConfiguration(
      devicePixelRatio: 1.0,
    ),
  );

  // Attach the render view to the pipeline
  pipelineOwner.rootNode = renderView;
  renderView.prepareInitialFrame();

  // Build the widget tree
  final RenderObjectToWidgetElement<RenderBox> rootElement =
      RenderObjectToWidgetAdapter<RenderBox>(
    container: renderView,
  ).attachToRenderTree(buildOwner, null);

  // Perform layout and painting
  buildOwner.buildScope(rootElement);
  pipelineOwner.flushLayout();
  pipelineOwner.flushCompositingBits();
  pipelineOwner.flushPaint();

  // Find the RenderRepaintBoundary
  final RenderRepaintBoundary boundary = repaintBoundaryKey.currentContext!
      .findRenderObject()! as RenderRepaintBoundary;

  // Capture the image
  final ui.Image image = await boundary.toImage();

  // Clean up
  pipelineOwner.rootNode = null;
  buildOwner.finalizeTree();

  return image;
}
