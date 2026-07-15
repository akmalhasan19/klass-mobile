"""Master template registry for PPTX generation.

Provides the ``TemplateRegistry`` which loads master ``.pptx`` templates
and their corresponding manifest files at startup, validates shape names,
and serves them to the Template Injector pipeline.
"""