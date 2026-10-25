import '../l10n/l10n.dart';
import '../models/chapter_story.dart';

/// Historias que aparecen al terminar cada capítulo.
/// Los textos están en los archivos de traducción (lib/l10n/*.arb),
/// con claves storyMCHeading/Destination/Narrative/Objective (M = mundo,
/// C = capítulo).
class ChapterStoryService {
  ChapterStoryService._();

  static ChapterStory? afterChapter(int world, int chapter) {
    final l = L10n.current;
    return switch ('${world}_$chapter') {
      '1_1' => ChapterStory(
        heading: l.story11Heading,
        destination: l.story11Destination,
        narrative: l.story11Narrative,
        objective: l.story11Objective,
      ),
      '1_2' => ChapterStory(
        heading: l.story12Heading,
        destination: l.story12Destination,
        narrative: l.story12Narrative,
        objective: l.story12Objective,
      ),
      '1_3' => ChapterStory(
        heading: l.story13Heading,
        destination: l.story13Destination,
        narrative: l.story13Narrative,
        objective: l.story13Objective,
      ),
      '2_1' => ChapterStory(
        heading: l.story21Heading,
        destination: l.story21Destination,
        narrative: l.story21Narrative,
        objective: l.story21Objective,
      ),
      '2_2' => ChapterStory(
        heading: l.story22Heading,
        destination: l.story22Destination,
        narrative: l.story22Narrative,
        objective: l.story22Objective,
      ),
      '2_3' => ChapterStory(
        heading: l.story23Heading,
        destination: l.story23Destination,
        narrative: l.story23Narrative,
        objective: l.story23Objective,
      ),
      '3_1' => ChapterStory(
        heading: l.story31Heading,
        destination: l.story31Destination,
        narrative: l.story31Narrative,
        objective: l.story31Objective,
      ),
      '3_2' => ChapterStory(
        heading: l.story32Heading,
        destination: l.story32Destination,
        narrative: l.story32Narrative,
        objective: l.story32Objective,
      ),
      '3_3' => ChapterStory(
        heading: l.story33Heading,
        destination: l.story33Destination,
        narrative: l.story33Narrative,
        objective: l.story33Objective,
      ),
      '4_1' => ChapterStory(
        heading: l.story41Heading,
        destination: l.story41Destination,
        narrative: l.story41Narrative,
        objective: l.story41Objective,
      ),
      '4_2' => ChapterStory(
        heading: l.story42Heading,
        destination: l.story42Destination,
        narrative: l.story42Narrative,
        objective: l.story42Objective,
      ),
      '4_3' => ChapterStory(
        heading: l.story43Heading,
        destination: l.story43Destination,
        narrative: l.story43Narrative,
        objective: l.story43Objective,
      ),
      _ => null,
    };
  }
}
