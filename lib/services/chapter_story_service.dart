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
      '5_1' => ChapterStory(
        heading: l.story51Heading,
        destination: l.story51Destination,
        narrative: l.story51Narrative,
        objective: l.story51Objective,
      ),
      '5_2' => ChapterStory(
        heading: l.story52Heading,
        destination: l.story52Destination,
        narrative: l.story52Narrative,
        objective: l.story52Objective,
      ),
      '5_3' => ChapterStory(
        heading: l.story53Heading,
        destination: l.story53Destination,
        narrative: l.story53Narrative,
        objective: l.story53Objective,
      ),
      '6_1' => ChapterStory(
        heading: l.story61Heading,
        destination: l.story61Destination,
        narrative: l.story61Narrative,
        objective: l.story61Objective,
      ),
      '6_2' => ChapterStory(
        heading: l.story62Heading,
        destination: l.story62Destination,
        narrative: l.story62Narrative,
        objective: l.story62Objective,
      ),
      '6_3' => ChapterStory(
        heading: l.story63Heading,
        destination: l.story63Destination,
        narrative: l.story63Narrative,
        objective: l.story63Objective,
      ),
      _ => null,
    };
  }
}
